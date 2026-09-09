import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../utils/number_to_words.dart';

double _parseDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? fallback;
}

int _parseInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? fallback;
}

/// Single-page responsive multi-lot live bidding room.
/// 
/// Security & UX guarantees:
/// 1. Credential Gate: Bidders must authenticate for each room with room credentials.
///    No automatic bypass from regular website login. Leaving a room clears the session.
/// 2. Strict Per-Lot Isolation: Bidding or leading on Lot 1 never locks Lot 2 or Lot 3.
/// 3. Synchronized Sorting: Lot ordering matches the modal and backend precisely.
/// 4. Rich Information: Lot titles, item names, and descriptions are prominently displayed.
/// 5. Layout Stability: Quick-raise chips stay visible (disabled) during leading states.
/// 6. Friendly Timers: Multi-day auctions display readable day/hour/minute countdowns.
class LiveAuctionPage extends StatefulWidget {
  final String roomId;
  final String roomTitle;

  const LiveAuctionPage({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  @override
  State<LiveAuctionPage> createState() => _LiveAuctionPageState();
}

class _LiveAuctionPageState extends State<LiveAuctionPage> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _loginErrorMessage;
  int? _selectedLotTab; // 0: All, 1: Live, 2: Upcoming, 3: Ended

  String? _groupId;
  String? _groupTitle;
  List<Map<String, dynamic>> _categories = [];
  String? _sessionToken;
  Set<String>? _approvedRoomIds;

  // Independent state per room: roomId -> roomState
  final Map<String, Map<String, dynamic>> _roomStates = {};

  // Active WebSocket channels per room: roomId -> channel
  final Map<String, WebSocketChannel> _roomChannels = {};

  Timer? _countdownTimer;
  final Stopwatch _monotonicClock = Stopwatch();
  bool _isSpectator = false;
  String? _userRole;

  final TextEditingController _tempEmailController = TextEditingController();
  final TextEditingController _tempPasswordController = TextEditingController();

  void _log(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    debugPrint('[LIVE_BID $time] $message');
    print('[LIVE_BID $time] $message');
  }

  String _extractErrorMessage(dynamic error, {String fallback = 'These bidding credentials are not authorized for this auction room.'}) {
    if (error == null) return fallback;
    if (error is String) {
      final trimmed = error.trim();
      return trimmed.isNotEmpty ? trimmed : fallback;
    }
    if (error is Map) {
      if (error['error'] != null) {
        return _extractErrorMessage(error['error'], fallback: fallback);
      }
      if (error['detail'] != null) {
        return _extractErrorMessage(error['detail'], fallback: fallback);
      }
      if (error['message'] != null) {
        return _extractErrorMessage(error['message'], fallback: fallback);
      }
      if (error['non_field_errors'] != null) {
        return _extractErrorMessage(error['non_field_errors'], fallback: fallback);
      }
      final firstVal = error.values.firstOrNull;
      if (firstVal != null) {
        return _extractErrorMessage(firstVal, fallback: fallback);
      }
    }
    if (error is List) {
      final nonNullItems = error.where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      if (nonNullItems.isNotEmpty) {
        return _extractErrorMessage(nonNullItems.first, fallback: fallback);
      }
    }
    final s = error.toString().trim();
    return s.isNotEmpty ? s : fallback;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monotonicClock.start();
    _initPage();
  }

  Future<void> _initPage() async {
    await _fetchGroupCategoriesAndInit(showLoading: true);
    await _checkRoleAndAutoConnect();
    _startGlobalCountdownTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    for (var ch in _roomChannels.values) {
      try {
        ch.sink.close();
      } catch (_) {}
    }
    _roomChannels.clear();
    for (var state in _roomStates.values) {
      (state['bidController'] as TextEditingController?)?.dispose();
    }
    _roomStates.clear();
    _tempEmailController.dispose();
    _tempPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      // A Dart periodic timer may be paused while the app is backgrounded.
      // Refresh from the server before the bidder can act on an old display.
      _refreshCategories();
    }
  }

  void _syncCountdown(Map<String, dynamic> state, int seconds) {
    state['timeRemainingSec'] = seconds < 0 ? 0 : seconds;
    state['timerSyncedAtMs'] = _monotonicClock.elapsedMilliseconds;
  }

  int _remainingSeconds(Map<String, dynamic> state) {
    final int syncedSeconds = _parseInt(state['timeRemainingSec'], 0);
    final int syncedAtMs = _parseInt(state['timerSyncedAtMs'], _monotonicClock.elapsedMilliseconds);
    final int elapsedSeconds = (((_monotonicClock.elapsedMilliseconds - syncedAtMs) ~/ 1000)
        .clamp(0, syncedSeconds) as int);
    return syncedSeconds - elapsedSeconds;
  }

  Future<void> _fetchGroupCategoriesAndInit({String? sessionToken, bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final activeSession = sessionToken ?? _sessionToken;
      final groupResult = await ApiService.getGroupCategories(
        widget.roomId,
        sessionToken: activeSession,
      );
      if (groupResult['success'] == true && mounted) {
        final data = groupResult['data'] as Map<String, dynamic>;
        _groupId = data['group_id']?.toString();
        _groupTitle = data['group_title']?.toString() ?? widget.roomTitle;
        final rawList = (data['categories'] as List<dynamic>?) ?? [];

        var parsedList = rawList.map((c) => Map<String, dynamic>.from(c as Map)).toList();

        // For non-spectator bidders, synchronize approved room IDs
        if (!_isSpectator) {
          for (var cat in parsedList) {
            final rId = cat['id']?.toString() ?? '';
            if (cat['is_approved'] == true && rId.isNotEmpty) {
              _approvedRoomIds ??= <String>{};
              _approvedRoomIds!.add(rId);
            }
          }
          if (_approvedRoomIds != null && _approvedRoomIds!.isNotEmpty) {
            parsedList = parsedList.where((cat) {
              final rId = cat['id']?.toString() ?? '';
              return _approvedRoomIds!.contains(rId) || cat['is_approved'] == true;
            }).toList();
          }
        }

        _categories = parsedList;

        // Sort categories by created_at ascending (fallback to id) so ordering strictly matches modal
        _categories.sort((a, b) {
          final aCreated = a['created_at']?.toString() ?? '';
          final bCreated = b['created_at']?.toString() ?? '';
          if (aCreated.isNotEmpty && bCreated.isNotEmpty) {
            return aCreated.compareTo(bCreated);
          }
          final aId = a['id']?.toString() ?? '';
          final bId = b['id']?.toString() ?? '';
          return aId.compareTo(bId);
        });

        // Initialize independent state for each category room with safe type parsing
        for (var cat in _categories) {
          final rId = cat['id']?.toString() ?? '';
          if (rId.isEmpty) continue;

          final itemMap = (cat['item'] is Map) ? Map<String, dynamic>.from(cat['item'] as Map) : <String, dynamic>{};
          final minBid = _parseDouble(itemMap['min_bid'] ?? cat['min_bid'], 0.0);
          final minRaise = _parseDouble(itemMap['min_raise'] ?? cat['min_raise'], 100.0);
          final currentBid = _parseDouble(cat['current_bid'], minBid);
          final timeRem = _parseInt(cat['time_remaining_sec'], 0);
          final winnerMap = (cat['winner'] is Map) ? (cat['winner'] as Map) : null;

          final status = cat['status']?.toString() ?? 'upcoming';
          final isEnded = status == 'ended' || (status == 'live' && timeRem == 0);

          if (_roomStates.containsKey(rId)) {
            final existing = _roomStates[rId]!;
            existing['title'] = cat['title']?.toString() ?? existing['title'];
            existing['category'] = cat['category']?.toString() ?? existing['category'];
            existing['subcategory'] = cat['subcategory']?.toString() ?? existing['subcategory'];
            existing['item'] = itemMap;
            existing['status'] = status;
            _syncCountdown(existing, timeRem);
            existing['auctionEnded'] = isEnded;
            existing['minBid'] = minBid;
            existing['minRaise'] = minRaise;
            if (existing['isFirstBid'] == true) {
              existing['currentBid'] = minBid;
            } else {
              existing['currentBid'] = currentBid;
            }
            existing['scheduledStart'] = cat['scheduled_start']?.toString() ?? existing['scheduledStart'];
            existing['scheduledEnd'] = cat['scheduled_end']?.toString() ?? existing['scheduledEnd'];
            if (winnerMap != null) {
              existing['winningBid'] = _parseDouble(winnerMap['bid_amount'], 0.0);
              existing['winnerAlias'] = cat['winner']?['user_id']?.toString();
            }
          } else {
            _roomStates[rId] = {
              'roomId': rId,
              'title': cat['title']?.toString() ?? '',
              'category': cat['category']?.toString() ?? '',
              'subcategory': cat['subcategory']?.toString() ?? '',
              'item': itemMap,
              'currentBid': currentBid,
              'minBid': minBid,
              'minRaise': minRaise,
              'timeRemainingSec': timeRem,
              'timerSyncedAtMs': _monotonicClock.elapsedMilliseconds,
              'isHighestBidder': false,
              'isFirstBid': (cat['bids_count'] ?? 0) == 0,
              'status': status,
              'scheduledStart': cat['scheduled_start']?.toString(),
              'scheduledEnd': cat['scheduled_end']?.toString(),
              'auctionEnded': isEnded,
              'winnerAlias': cat['winner']?['user_id']?.toString(),
              'winningBid': winnerMap != null ? _parseDouble(winnerMap['bid_amount'], 0.0) : null,
              'myAlias': null,
              'bidController': TextEditingController(),
              'isSpectator': false,
              'isApproved': cat['is_approved'] == true,
            };
          }
        }
      }
    } catch (e, stack) {
      debugPrint("Error loading group categories: $e\n$stack");
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Rebuilds the countdown display. Remaining time is calculated from the
  /// monotonic elapsed-time anchor, not from the number of timer callbacks.
  void _startGlobalCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      bool needsRefresh = false;
      final now = DateTime.now();

      setState(() {
        for (var state in _roomStates.values) {
          final int rem = _remainingSeconds(state);
          bool ended = state['auctionEnded'] == true;
          String status = state['status']?.toString() ?? '';
          final int syncedSec = _parseInt(state['timeRemainingSec'], 0);
          // The remaining value is derived from monotonic elapsed time, so it
          // catches up after a delayed frame instead of losing paused seconds.
          // Only mark ended optimistically if it was counting down from an active positive timer.
          if (!ended && status == 'live' && syncedSec > 0 && rem <= 0) {
            state['auctionEnded'] = true;
            state['status'] = 'ended';
            _syncCountdown(state, 0);
          }

          // Automatically transition upcoming lots into live when scheduled start arrives
          if (!ended && status == 'upcoming') {
            final startStr = state['scheduledStart']?.toString();
            if (startStr != null && startStr.isNotEmpty) {
              final startDt = DateTime.tryParse(startStr);
              if (startDt != null && (now.isAfter(startDt) || now.isAtSameMomentAs(startDt))) {
                _log('Upcoming lot ${state['roomId']} scheduled start reached! Auto-transitioning to live.');
                state['status'] = 'live';
                state['auctionEnded'] = false;
                needsRefresh = true;
              }
            }
          }
        }
      });

      if (needsRefresh) {
        _refreshCategories();
      }
    });
  }

  /// Check user role: Admin gets spectator auto-connect.
  /// Bidders automatically re-authenticate via persisted room credentials so they stay logged in!
  Future<void> _checkRoleAndAutoConnect() async {
    if (_isAuthenticated) return;

    try {
      final profileResult = await ApiService.getProfile();
      if (!mounted) return;

      if (profileResult['success'] == true) {
        final role = profileResult['data']?['role'] as String?;
        _userRole = role;

        if (role == 'admin') {
          _isSpectator = true;
          await _connectAllRoomsForAdmin();
          return;
        }
      }
    } catch (_) {}

    // Check for saved room credentials to automatically log back into the room without re-prompting
    try {
      final savedCreds = await ApiService.getSavedRoomCredentials(widget.roomId);
      if (savedCreds != null && mounted) {
        _tempEmailController.text = savedCreds['email']!;
        _tempPasswordController.text = savedCreds['password']!;
        _log('Auto-authenticating with saved room credentials for ${savedCreds['email']}');
        await _performEphemeralLogin();
        if (_isAuthenticated) return;
      }
    } catch (e) {
      _log('Auto-login from saved credentials failed: $e');
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  /// Manual or background refresh of group categories without disrupting active session or WebSockets
  Future<void> _refreshCategories() async {
    await _fetchGroupCategoriesAndInit(sessionToken: _sessionToken, showLoading: false);

    // If any newly live room is not yet connected to WebSocket, connect it
    if (_sessionToken != null) {
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        final status = cat['status']?.toString();
        final state = _roomStates[rId];
        final isEnded = state?['auctionEnded'] == true || status == 'ended';
        if (rId.isNotEmpty && status == 'live' && !isEnded && !_roomChannels.containsKey(rId)) {
          _connectSingleRoomWebSocket(rId, _sessionToken!);
        }
      }
    }
  }

  /// Connect all rooms for Admin Spectator Mode
  Future<void> _connectAllRoomsForAdmin() async {
    setState(() {
      _isLoading = true;
      _isAuthenticated = true;
      _errorMessage = null;
    });

    try {
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        final status = cat['status']?.toString();
        final state = _roomStates[rId];
        final isEnded = state?['auctionEnded'] == true || status == 'ended';
        if (rId.isEmpty || status != 'live' || isEnded) continue;

        try {
          final tokenResult = await ApiService.getWebSocketToken(rId);
          if (tokenResult['success'] == true && tokenResult['token'] != null) {
            _connectSingleRoomWebSocket(rId, tokenResult['token']);
          }
        } catch (e) {
          debugPrint("Could not connect admin WS for room $rId: $e");
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Connect all group category rooms with the authenticated room session token
  Future<void> _connectAllRoomsWithSession(String sessionToken) async {
    setState(() {
      _isLoading = true;
      _isAuthenticated = true;
      _errorMessage = null;
    });

    try {
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        final status = cat['status']?.toString();
        final state = _roomStates[rId];
        final isEnded = state?['auctionEnded'] == true || status == 'ended';
        if (rId.isEmpty || status != 'live' || isEnded) continue;

        // Connect each room's WebSocket using the session token.
        // Backend consumers validate token and group authorization independently.
        _connectSingleRoomWebSocket(rId, sessionToken);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _connectSingleRoomWebSocket(String roomId, String token) {
    try {
      final baseWs = ApiService.baseUrl
          .replaceFirst(RegExp(r'^http'), 'ws')
          .replaceFirst('/api', '');

      final wsUrl = '$baseWs/ws/room/$roomId/';
      _log('CONNECTING Primary WS -> $wsUrl [subprotocols: $token, token.$token]');

      bool hasReceivedData = false;
      bool fallbackStarted = false;

      void startFallback() {
        if (fallbackStarted) return;
        fallbackStarted = true;
        _log('Triggering Fallback WS for room $roomId (query token)');
        _connectSingleRoomWebSocketFallback(roomId, token);
      }

      final channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: [token],
      );

      _roomChannels[roomId]?.sink.close();
      _roomChannels[roomId] = channel;

      channel.stream.listen(
        (message) {
          hasReceivedData = true;
          _log('WS RECEIVED [$roomId]: $message');
          final data = jsonDecode(message);
          _handleRoomWebSocketMessage(roomId, data);
        },
        onError: (error) {
          _log('WS ERROR [$roomId]: $error');
          if (!hasReceivedData) {
            startFallback();
          }
        },
        onDone: () {
          final code = channel.closeCode;
          final reason = channel.closeReason;
          _log('WS CLOSED [$roomId]: closeCode=$code, closeReason=$reason');
          if (identical(_roomChannels[roomId], channel)) {
            _roomChannels.remove(roomId);
          }
          if (code == 4403) {
            _log('  -> Hint: Server rejected with 4403 (Room not live, or bidder not approved for this lot)');
          } else if (code == 4401) {
            _log('  -> Hint: Server rejected with 4401 (Session token invalid or expired)');
          } else if (code == 4429) {
            _log('  -> Hint: Server rejected with 4429 (Too many simultaneous WS connections)');
          }
          if (!hasReceivedData) startFallback();
        },
      );
    } catch (e) {
      _log('WS EXCEPTION [$roomId]: $e');
      _connectSingleRoomWebSocketFallback(roomId, token);
    }
  }

  void _connectSingleRoomWebSocketFallback(String roomId, String token) {
    final baseWs = ApiService.baseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceFirst('/api', '');

    final wsUrl = '$baseWs/ws/room/$roomId/?token=$token';
    _log('CONNECTING Fallback WS -> $wsUrl');

    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _roomChannels[roomId]?.sink.close();
    _roomChannels[roomId] = channel;

    channel.stream.listen(
      (message) {
        _log('FALLBACK WS RECEIVED [$roomId]: $message');
        final data = jsonDecode(message);
        _handleRoomWebSocketMessage(roomId, data);
      },
      onError: (e) {
        _log('FALLBACK WS ERROR [$roomId]: $e');
        if (identical(_roomChannels[roomId], channel)) {
          _roomChannels.remove(roomId);
        }
      },
      onDone: () {
        final code = channel.closeCode;
        final reason = channel.closeReason;
        _log('FALLBACK WS CLOSED [$roomId]: closeCode=$code, closeReason=$reason');
        if (identical(_roomChannels[roomId], channel)) {
          _roomChannels.remove(roomId);
        }
      },
    );
  }

  /// Applies real-time group-level categories update received directly over WebSocket
  void _applyUpdatedCategories(List<dynamic> rawList, {String? newGroupTitle}) {
    if (!mounted) return;
    if (newGroupTitle != null && newGroupTitle.isNotEmpty) {
      _groupTitle = newGroupTitle;
    }
    final parsedList = rawList.map((c) => Map<String, dynamic>.from(c as Map)).toList();

    parsedList.sort((a, b) {
      final aCreated = a['created_at']?.toString() ?? '';
      final bCreated = b['created_at']?.toString() ?? '';
      if (aCreated.isNotEmpty && bCreated.isNotEmpty) {
        return aCreated.compareTo(bCreated);
      }
      final aId = a['id']?.toString() ?? '';
      final bId = b['id']?.toString() ?? '';
      return aId.compareTo(bId);
    });

    setState(() {
      _categories = parsedList;

      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        if (rId.isEmpty) continue;

        _approvedRoomIds ??= <String>{};
        _approvedRoomIds!.add(rId);

        final itemMap = (cat['item'] is Map) ? Map<String, dynamic>.from(cat['item'] as Map) : <String, dynamic>{};
        final minBid = _parseDouble(itemMap['min_bid'] ?? cat['min_bid'], 0.0);
        final minRaise = _parseDouble(itemMap['min_raise'] ?? cat['min_raise'], 100.0);
        final currentBid = _parseDouble(cat['current_bid'], minBid);
        final timeRem = _parseInt(cat['time_remaining_sec'], 0);
        final winnerMap = (cat['winner'] is Map) ? (cat['winner'] as Map) : null;
        final status = cat['status']?.toString() ?? 'upcoming';
        final isEnded = status == 'ended' || (status == 'live' && timeRem == 0);

        if (_roomStates.containsKey(rId)) {
          final existing = _roomStates[rId]!;
          existing['title'] = cat['title']?.toString() ?? existing['title'];
          existing['category'] = cat['category']?.toString() ?? existing['category'];
          existing['subcategory'] = cat['subcategory']?.toString() ?? existing['subcategory'];
          existing['item'] = itemMap;
          existing['status'] = status;
          existing['scheduledStart'] = cat['scheduled_start']?.toString() ?? existing['scheduledStart'];
          existing['scheduledEnd'] = cat['scheduled_end']?.toString() ?? existing['scheduledEnd'];
          existing['minBid'] = minBid;
          existing['minRaise'] = minRaise;
          if (existing['isFirstBid'] == true) {
            existing['currentBid'] = minBid;
          } else {
            existing['currentBid'] = _parseDouble(cat['current_bid'], existing['currentBid']);
          }
          _syncCountdown(existing, timeRem);
          existing['auctionEnded'] = isEnded;
          if (winnerMap != null) {
            existing['winningBid'] = _parseDouble(winnerMap['bid_amount'], 0.0);
            existing['winnerAlias'] = cat['winner']?['user_id']?.toString();
          }
        } else {
          _roomStates[rId] = {
            'roomId': rId,
            'title': cat['title']?.toString() ?? '',
            'category': cat['category']?.toString() ?? '',
            'subcategory': cat['subcategory']?.toString() ?? '',
            'item': itemMap,
            'currentBid': currentBid,
            'minBid': minBid,
            'minRaise': minRaise,
            'timeRemainingSec': timeRem,
            'timerSyncedAtMs': _monotonicClock.elapsedMilliseconds,
            'isHighestBidder': false,
            'isFirstBid': (cat['bids_count'] ?? 0) == 0,
            'status': status,
            'scheduledStart': cat['scheduled_start']?.toString(),
            'scheduledEnd': cat['scheduled_end']?.toString(),
            'auctionEnded': isEnded,
            'winnerAlias': cat['winner']?['user_id']?.toString(),
            'winningBid': winnerMap != null ? _parseDouble(winnerMap['bid_amount'], 0.0) : null,
            'myAlias': null,
            'bidController': TextEditingController(),
            'isSpectator': false,
            'isApproved': true,
          };
        }

        // Auto-connect WebSocket for any newly added or newly live lot immediately!
        if (status == 'live' && !isEnded && _sessionToken != null && !_roomChannels.containsKey(rId)) {
          _log('Auto-connecting WebSocket for live lot $rId...');
          _connectSingleRoomWebSocket(rId, _sessionToken!);
        }
      }
    });
  }

  void _handleRoomWebSocketMessage(String roomId, Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'];
    if (type == 'group_updated') {
      _log('GROUP UPDATED broadcast received for group=${data['group_id']}.');
      final rawCats = data['categories'];
      if (rawCats is List && rawCats.isNotEmpty) {
        _applyUpdatedCategories(rawCats, newGroupTitle: data['group_title']?.toString());
      } else {
        _refreshCategories();
      }
      return;
    }

    final roomData = (data['room'] is Map) ? Map<String, dynamic>.from(data['room'] as Map) : null;
    final targetRoomId = (roomData != null && roomData['id'] != null) ? roomData['id'].toString() : roomId;
    final state = _roomStates[targetRoomId] ?? _roomStates[roomId];

    if (type != 'room_updated' && state == null) return;

    setState(() {
      if (type == 'room_state') {
        if (state == null) return;
        if (data['current_bid'] != null) state['currentBid'] = _parseDouble(data['current_bid'], state['currentBid']);
        if (data['min_bid'] != null) state['minBid'] = _parseDouble(data['min_bid'], state['minBid']);
        if (data['min_raise'] != null) state['minRaise'] = _parseDouble(data['min_raise'], state['minRaise']);
        if (data['time_remaining_sec'] != null) {
          _syncCountdown(state, _parseInt(data['time_remaining_sec'], state['timeRemainingSec']));
        }
        if (data['extension_count'] != null) {
          state['extensionCount'] = _parseInt(data['extension_count'], 0);
        }
        if (data['max_extensions'] != null) {
          state['maxExtensions'] = _parseInt(data['max_extensions'], 10);
        }
        state['isHighestBidder'] = data['is_highest_bidder'] == true;
        state['isFirstBid'] = data['is_first_bid'] == true;

        if (data['bidder_alias'] != null) {
          state['myAlias'] = data['bidder_alias'].toString();
        }

        if (data['is_spectator'] == true) {
          _isSpectator = true;
          state['isSpectator'] = true;
        }
      } else if (type == 'new_bid') {
        if (state == null) return;
        final double newAmt = _parseDouble(data['amount'], 0.0);
        final String newAlias = data['bidder_alias']?.toString() ?? 'Unknown';

        state['currentBid'] = newAmt;
        state['isFirstBid'] = false;
        // Strictly evaluate highest bidder for THIS specific room independently
        state['isHighestBidder'] = (data['is_highest_bidder'] == true) ||
            (state['myAlias'] != null && newAlias == state['myAlias']);

        if (data['seconds_remaining'] != null || data['time_remaining_sec'] != null) {
          final secs = _parseInt(data['seconds_remaining'] ?? data['time_remaining_sec'], state['timeRemainingSec']);
          _syncCountdown(state, secs);
        }

        if (data['extension_count'] != null) {
          state['extensionCount'] = _parseInt(data['extension_count'], state['extensionCount'] ?? 0);
        }
        if (data['max_extensions'] != null) {
          state['maxExtensions'] = _parseInt(data['max_extensions'], state['maxExtensions'] ?? 10);
        }

        if (data['extended'] == true || data['is_extended'] == true) {
          final int extRound = _parseInt(data['extension_count'], state['extensionCount'] ?? 1);
          final String lotName = state['title']?.toString() ?? 'Lot';

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.more_time_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bid placed in final minute! $lotName extended by 3 minutes (Overtime Round $extRound)!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0288D1),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (type == 'bid_deleted') {
        if (state != null) {
          final double newAmt = _parseDouble(data['amount'], 0.0);
          final String? newAlias = data['bidder_alias']?.toString();
          final int deletedSeq = _parseInt(data['deleted_seq'], 0);

          state['currentBid'] = newAmt;
          state['isFirstBid'] = (data['is_first_bid'] == true) || (newAmt <= (state['minBid'] ?? 0.0));
          state['isHighestBidder'] = (data['is_highest_bidder'] == true) ||
              (state['myAlias'] != null && newAlias != null && newAlias == state['myAlias']);

          // Remove deleted bid from any cached bid lists
          if (state['bids'] is List) {
            (state['bids'] as List).removeWhere(
              (b) => _parseInt(b['seq'] ?? b['sequence_number'], -1) == deletedSeq,
            );
          }

          final String lotName = state['title']?.toString() ?? 'Lot';
          final String msg = data['message']?.toString() ?? 'Bid #$deletedSeq was retracted by administrator.';

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$lotName: $msg',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFD32F2F),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (type == 'auction_extended') {
        if (state != null) {
          if (data['seconds_remaining'] != null || data['time_remaining_sec'] != null) {
            final secs = _parseInt(data['seconds_remaining'] ?? data['time_remaining_sec'], state['timeRemainingSec']);
            _syncCountdown(state, secs);
          }
          if (data['extension_count'] != null) {
            state['extensionCount'] = _parseInt(data['extension_count'], state['extensionCount'] ?? 0);
          }
          if (data['max_extensions'] != null) {
            state['maxExtensions'] = _parseInt(data['max_extensions'], state['maxExtensions'] ?? 10);
          }
          state['auctionEnded'] = false;
          state['status'] = 'live';
        }
        final int extRound = _parseInt(data['extension_count'], state?['extensionCount'] ?? 1);
        final String lotName = state?['title']?.toString() ?? 'Lot';

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.more_time_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bid placed in final minute! $lotName extended by 3 minutes (Overtime Round $extRound)!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0288D1),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (type == 'countdown_tick') {
        if (state == null) return;
        final secs = _parseInt(data['seconds_remaining'], state['timeRemainingSec']);
        if (state['auctionEnded'] != true) {
          _syncCountdown(state, secs);
          if (secs <= 0) {
            state['auctionEnded'] = true;
            state['status'] = 'ended';
            _syncCountdown(state, 0);
          }
        }
      } else if (type == 'room_updated') {
        // Every mutable live-auction field is pushed by the admin update path.
        final room = roomData ?? <String, dynamic>{};
        final item = room['item'] is Map ? Map<String, dynamic>.from(room['item'] as Map) : <String, dynamic>{};

        var targetState = _roomStates[targetRoomId];
        if (targetState == null) {
          targetState = {
            'roomId': targetRoomId,
            'title': room['title']?.toString() ?? '',
            'category': room['category']?.toString() ?? '',
            'subcategory': room['subcategory']?.toString() ?? '',
            'item': item,
            'currentBid': _parseDouble(item['min_bid'], 0.0),
            'minBid': _parseDouble(item['min_bid'], 0.0),
            'minRaise': _parseDouble(item['min_raise'], 100.0),
            'timeRemainingSec': _parseInt(data['seconds_remaining'], 0),
            'timerSyncedAtMs': _monotonicClock.elapsedMilliseconds,
            'isHighestBidder': false,
            'isFirstBid': true,
            'status': room['status']?.toString() ?? 'live',
            'scheduledStart': room['scheduled_start']?.toString(),
            'scheduledEnd': room['scheduled_end']?.toString(),
            'auctionEnded': false,
            'bidController': TextEditingController(),
            'isSpectator': false,
            'isApproved': true,
          };
          _roomStates[targetRoomId] = targetState;
          _approvedRoomIds ??= <String>{};
          _approvedRoomIds!.add(targetRoomId);
        } else {
          targetState['title'] = room['title']?.toString() ?? targetState['title'];
          targetState['category'] = room['category']?.toString() ?? targetState['category'];
          targetState['subcategory'] = room['subcategory']?.toString() ?? targetState['subcategory'];
          targetState['item'] = item;
          targetState['status'] = room['status']?.toString() ?? targetState['status'];
          targetState['scheduledStart'] = room['scheduled_start']?.toString() ?? targetState['scheduledStart'];
          targetState['scheduledEnd'] = room['scheduled_end']?.toString() ?? targetState['scheduledEnd'];
          targetState['minBid'] = _parseDouble(item['min_bid'], targetState['minBid']);
          targetState['minRaise'] = _parseDouble(item['min_raise'], targetState['minRaise']);
          if (targetState['isFirstBid'] == true) {
            targetState['currentBid'] = targetState['minBid'];
          }
        }

        if (data['seconds_remaining'] != null) {
          _syncCountdown(targetState, _parseInt(data['seconds_remaining'], targetState['timeRemainingSec']));
        }
        final ended = targetState['status'] == 'ended' || _remainingSeconds(targetState) <= 0;
        targetState['auctionEnded'] = ended;

        // Also update matching item in _categories so thumbnail / card re-renders title, unit, quantity
        final catIdx = _categories.indexWhere((c) => c['id']?.toString() == targetRoomId);
        if (catIdx != -1) {
          _categories[catIdx]['title'] = targetState['title'];
          _categories[catIdx]['category'] = targetState['category'];
          _categories[catIdx]['subcategory'] = targetState['subcategory'];
          _categories[catIdx]['item'] = item;
          _categories[catIdx]['status'] = targetState['status'];
          _categories[catIdx]['min_bid'] = targetState['minBid'];
          _categories[catIdx]['min_raise'] = targetState['minRaise'];
          _categories[catIdx]['scheduled_start'] = targetState['scheduledStart'];
          _categories[catIdx]['scheduled_end'] = targetState['scheduledEnd'];
          if (targetState['isFirstBid'] == true) {
            _categories[catIdx]['current_bid'] = targetState['currentBid'];
          }
        } else {
          _categories.add({
            'id': targetRoomId,
            'title': targetState['title'],
            'category': targetState['category'],
            'subcategory': targetState['subcategory'],
            'item': item,
            'status': targetState['status'],
            'min_bid': targetState['minBid'],
            'min_raise': targetState['minRaise'],
            'scheduled_start': targetState['scheduledStart'],
            'scheduled_end': targetState['scheduledEnd'],
            'current_bid': targetState['currentBid'],
            'is_approved': true,
          });
        }

        // Auto-connect WebSocket if room became live and channel is missing
        if (targetState['status'] == 'live' && !ended && _sessionToken != null && !_roomChannels.containsKey(targetRoomId)) {
          _log('Auto-connecting WebSocket for live room $targetRoomId...');
          _connectSingleRoomWebSocket(targetRoomId, _sessionToken!);
        }
      } else if (type == 'auction_ended') {
        if (state == null) return;
        // Server confirmed auction is over — freeze immediately regardless of local timer.
        state['auctionEnded'] = true;
        state['status'] = 'ended';
        state['winnerAlias'] = data['winner_alias']?.toString();
        state['winningBid'] = _parseDouble(data['winning_bid'], 0.0);
      } else if (type == 'error' || type == 'bid_rejected') {
        String errorMsg = data['message']?.toString() ?? '';
        final reason = data['reason']?.toString();
        if (errorMsg.isEmpty) {
          if (reason == 'self_outbid_restricted') {
            errorMsg = 'You are already the highest bidder on this lot.';
          } else if (reason == 'first_bid_cap_exceeded') {
            final maxFirst = data['max_first_bid'];
            errorMsg = maxFirst != null
                ? 'The 1st bid cannot exceed ₹${_formatCurrency(_parseDouble(maxFirst))} (10x starting price).'
                : '1st bid cannot exceed 10x starting price.';
          } else if (reason == 'below_minimum') {
            final minNext = data['min_next_bid'];
            errorMsg = minNext != null
                ? 'Bid must be at least ₹${_formatCurrency(_parseDouble(minNext))}.'
                : 'Bid is below minimum required raise.';
          } else if (reason == 'auction_ended') {
            errorMsg = 'This lot has concluded. No more bids accepted.';
          } else {
            errorMsg = 'Bid could not be accepted.';
          }
        }
        // CRITICAL: if server rejected because auction ended, immediately mark this room as ended
        // so the Bid Now button is disabled. Timer display will show ENDED via the 'ended' flag.
        // Do NOT zero timeRemainingSec — no jarring number jump for the bidder.
        if (reason == 'auction_ended' ||
            errorMsg.toLowerCase().contains('already ended') ||
            errorMsg.toLowerCase().contains('auction has ended') ||
            errorMsg.toLowerCase().contains('concluded')) {
          if (state != null) {
            state['auctionEnded'] = true;
            state['status'] = 'ended';
          }
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    });
  }

  String _formatCurrency(num amount) {
    return formatCurrency(amount, withSymbol: false);
  }

  /// Formats seconds into a human-friendly countdown display.
  /// If > 24h: e.g. "7d 23h 40m" (instead of raw 191 hours)
  /// If < 24h: e.g. "14:32:05"
  /// If < 1h:  e.g. "25:40"
  String _formatTimerDisplay(int seconds) {
    if (seconds <= 0) return 'ENDED';
    final int days = seconds ~/ 86400;
    final int remaining = seconds % 86400;
    final int h = remaining ~/ 3600;
    final int m = (remaining % 3600) ~/ 60;
    final int s = remaining % 60;

    if (days > 0) {
      return '${days}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    } else if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _performEphemeralLogin() async {
    final email = _tempEmailController.text.trim();
    final password = _tempPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginErrorMessage = 'Both email and password are required.');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both email and password are required.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loginErrorMessage = null;
    });

    _log('EPHEMERAL LOGIN REQUEST: email=$email, roomId=${widget.roomId}');
    final result = await ApiService.ephemeralLogin(email, password, roomId: widget.roomId);

    if (!mounted) return;

    if (result['success'] == true) {
      final String sessionToken = result['token']?.toString() ?? '';
      _sessionToken = sessionToken;

      final approvedList = (result['approved_room_ids'] ?? result['approvedRoomIds']) as List?;
      if (approvedList != null && approvedList.isNotEmpty) {
        _approvedRoomIds = approvedList.map((e) => e.toString()).toSet();
      }
      _log('EPHEMERAL LOGIN SUCCESS: token=$sessionToken, approvedLots=$_approvedRoomIds');

      // Re-fetch categories passing the authenticated sessionToken
      // Backend GroupCategoriesView will now strictly return only approved lots for this bidder
      await _fetchGroupCategoriesAndInit(sessionToken: sessionToken);

      // Client-side guard: filter _categories strictly to approved lots
      if (_approvedRoomIds != null && !_isSpectator) {
        _categories = _categories.where((cat) {
          final rId = cat['id']?.toString() ?? '';
          return _approvedRoomIds!.contains(rId);
        }).toList();
      }

      // STRICT VALIDATION: If this bidder has NO approved lots in this group auction room,
      // stop them at the login screen immediately and do NOT proceed into the bidding room.
      final validCategories = _categories.where((cat) {
        if (_isSpectator) return true;
        final rId = cat['id']?.toString() ?? '';
        if (_approvedRoomIds != null && _approvedRoomIds!.isNotEmpty) {
          return _approvedRoomIds!.contains(rId);
        }
        return cat['is_approved'] == true;
      }).toList();

      if (!_isSpectator && validCategories.isEmpty) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
          _sessionToken = null;
          _approvedRoomIds = null;
          _loginErrorMessage = 'These bidding credentials are not authorized for this auction room.';
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('These bidding credentials are not authorized for this auction room.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      _loginErrorMessage = null;
      await ApiService.saveRoomCredentials(widget.roomId, email, password);
      await _connectAllRoomsWithSession(sessionToken);
    } else {
      // Fallback check: if user entered standard login email
      if (!email.contains('@auction.internal')) {
        final standardResult = await ApiService.login(email, password);
        if (standardResult['success'] == true && mounted) {
          final profileResult = await ApiService.getProfile();
          final role = profileResult['data']?['role'] as String?;
          if (role == 'admin') {
            _isSpectator = true;
            await _connectAllRoomsForAdmin();
            return;
          } else {
            // Standard bidder login: re-fetch categories using authenticated JWT
            await _fetchGroupCategoriesAndInit();

            // Client-side guard: filter by is_approved
            _categories = _categories.where((cat) => cat['is_approved'] == true).toList();
            _approvedRoomIds = _categories.map((c) => c['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

            if (_categories.isEmpty) {
              setState(() {
                _isLoading = false;
                _isAuthenticated = false;
                _sessionToken = null;
                _approvedRoomIds = null;
                _loginErrorMessage = 'These bidding credentials are not authorized for this auction room.';
              });
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('These bidding credentials are not authorized for this auction room.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }

            try {
              final wsResult = await ApiService.getWebSocketToken(widget.roomId);
              if (wsResult['success'] == true && wsResult['token'] != null) {
                final wsToken = wsResult['token'].toString();
                _sessionToken = wsToken;
                _loginErrorMessage = null;
                await ApiService.saveRoomCredentials(widget.roomId, email, password);
                await _connectAllRoomsWithSession(wsToken);
                return;
              }
            } catch (_) {}
          }
        }
      }

      final errorMsg = _extractErrorMessage(result['error']);
      setState(() {
        _isLoading = false;
        _loginErrorMessage = errorMsg;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Place bid independently on a specific lot room
  void _placeBidForRoom(String roomId, [double? presetAmount]) {
    final state = _roomStates[roomId];
    if (state == null) return;

    final status = state['status']?.toString();
    final isEnded = state['auctionEnded'] == true || status == 'ended';
    if (status != 'live' || isEnded) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bidding is only permitted on active, live lots.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isSpectator || state['isSpectator'] == true) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spectator mode: Bidding is disabled.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Check highest bidder ONLY for THIS room
    if (state['isHighestBidder'] == true) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You currently hold the highest bid on this lot.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final controller = state['bidController'] as TextEditingController;
    double? amount = presetAmount;
    if (amount == null) {
      if (controller.text.isEmpty) return;
      amount = double.tryParse(controller.text.trim().replaceAll(',', ''));
    }

    if (amount != null) {
      amount = double.parse(amount.toStringAsFixed(2));
    }

    final double currentBid = _parseDouble(state['currentBid'], 0.0);
    if (amount == null || amount <= currentBid) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid must be higher than current bid (₹${_formatCurrency(currentBid)})')),
      );
      return;
    }

    // 10x Bid Cap Protection (10x starting price for 1st bid, 10x current highest bid thereafter)
    final double startingPrice = _parseDouble(state['minBid'], 0.0);
    final bool isFirst = state['isFirstBid'] == true;
    final double maxAllowed = isFirst ? (startingPrice * 10) : (currentBid * 10);
    if (maxAllowed > 0 && amount > maxAllowed) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFirst
                ? '1st bid cannot exceed ₹${_formatCurrency(maxAllowed)} (10x starting price).'
                : 'Bid cannot exceed ₹${_formatCurrency(maxAllowed)} (10x current bid ₹${_formatCurrency(currentBid)}).',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final channel = _roomChannels[roomId];
    _log('PLACE BID: room=$roomId, amount=$amount, currentBid=$currentBid, hasChannel=${channel != null}');
    if (channel != null) {
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
        final payload = jsonEncode({
          "type": "place_bid",
          "amount": amount,
        });
        _log('SENDING BID PAYLOAD [$roomId]: $payload');
        channel.sink.add(payload);
        controller.clear();
      } catch (e) {
        _log('CANNOT BID: Channel error for room $roomId: $e. Reconnecting...');
        _roomChannels.remove(roomId);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection lost. Reconnecting to lot...')),
        );
        if (_sessionToken != null) {
          _connectSingleRoomWebSocket(roomId, _sessionToken!);
        }
      }
    } else {
      _log('CANNOT BID: Channel is null or disconnected for room $roomId. Reconnecting...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to this lot room. Reconnecting...')),
      );
      if (_sessionToken != null) {
        _connectSingleRoomWebSocket(roomId, _sessionToken!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth >= 1100 ? 3 : (screenWidth >= 650 ? 2 : 1);

    // Filter categories strictly to approved lots for bidders (spectators/admins/testers see all)
    final validCategories = _categories.where((cat) {
      if (_isSpectator || _userRole == 'test_bidder' || _userRole == 'admin') return true;
      final rId = cat['id']?.toString() ?? '';
      if (_approvedRoomIds != null && _approvedRoomIds!.isNotEmpty) {
        return _approvedRoomIds!.contains(rId) || cat['is_approved'] == true;
      }
      return cat['is_approved'] == true;
    }).toList();

    if (!_isSpectator && validCategories.isEmpty) {
      _loginErrorMessage ??= 'These bidding credentials are not authorized for this auction room.';
      return _buildLoginScreen();
    }

    // Classify lots strictly: LIVE, UPCOMING, and ENDED from approved lots
    final liveLots = validCategories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return status == 'live' && !isEnded;
    }).toList();

    final upcomingLots = validCategories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return status == 'upcoming' && !isEnded;
    }).toList();

    final endedLots = validCategories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return isEnded;
    }).toList();

    final int currentTab = _selectedLotTab ?? (liveLots.isNotEmpty ? 1 : (upcomingLots.isNotEmpty ? 2 : 0));

    List<Map<String, dynamic>> displayedLots;
    switch (currentTab) {
      case 1:
        displayedLots = liveLots;
        break;
      case 2:
        displayedLots = upcomingLots;
        break;
      case 3:
        displayedLots = endedLots;
        break;
      case 0:
      default:
        displayedLots = validCategories;
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groupTitle ?? widget.roomTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              liveLots.isNotEmpty
                  ? (_isSpectator
                      ? 'Live Bidding • ${liveLots.length} Live Lot${liveLots.length == 1 ? '' : 's'}'
                      : 'Live Bidding • ${liveLots.length} Approved Live Lot${liveLots.length == 1 ? '' : 's'}')
                  : (upcomingLots.isNotEmpty
                      ? 'Upcoming Event Lots (${upcomingLots.length})'
                      : 'Auction Event Concluded'),
              style: TextStyle(
                fontSize: 11,
                color: liveLots.isNotEmpty ? const Color(0xFF0288D1) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Bidding Room',
            onPressed: () => _refreshCategories(),
          ),
          if (!_isSpectator)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Account & Session',
              onSelected: (val) async {
                if (val == 'logout') {
                  await ApiService.clearRoomCredentials(widget.roomId);
                  if (mounted) {
                    setState(() {
                      _isAuthenticated = false;
                      _sessionToken = null;
                      _approvedRoomIds = null;
                      _tempPasswordController.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out of this bidding room.')),
                    );
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout / Switch Account', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : validCategories.isEmpty
                  ? Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        padding: const EdgeInsets.all(28),
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Approved Lots Available',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You are not currently approved to bid on any lots in this auction event. Please contact the auction administrator to approve your participation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Return to Auctions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isSpectator)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.visibility, color: Color(0xFF059669), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Admin Spectator Mode — Watching live group auction. Bidding disabled.',
                                      style: TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── Lots Tab Filter Bar ────────────────────────────
                          _buildLotsFilterTabBar(
                            currentTab: currentTab,
                            allCount: validCategories.length,
                            liveCount: liveLots.length,
                            upcomingCount: upcomingLots.length,
                            endedCount: endedLots.length,
                          ),
                          const SizedBox(height: 14),

                          // ── Lots Grid or Empty View ────────────────────────
                          if (displayedLots.isEmpty)
                            _buildEmptyLotsView(
                              tabIndex: currentTab,
                              allCount: validCategories.length,
                              liveCount: liveLots.length,
                              upcomingCount: upcomingLots.length,
                              endedCount: endedLots.length,
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final double width = constraints.maxWidth;
                                int crossAxisCount = width >= 1100 ? 3 : (width >= 650 ? 2 : 1);
                                const double spacing = 14.0;
                                final double calcWidth = (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                                final double cardWidth = calcWidth > 260.0 ? calcWidth : width;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: List.generate(displayedLots.length, (idx) {
                                    final cat = displayedLots[idx];
                                    final rId = cat['id']?.toString() ?? '';
                                    final originalIdx = validCategories.indexWhere((c) => c['id']?.toString() == rId);
                                    return SizedBox(
                                      width: cardWidth,
                                      child: _buildLotCard(rId, originalIdx != -1 ? originalIdx : idx),
                                    );
                                  }),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildLotsFilterTabBar({
    required int currentTab,
    required int allCount,
    required int liveCount,
    required int upcomingCount,
    required int endedCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 480;
          return Row(
            children: [
              _buildFilterTabItem(
                index: 0,
                label: isNarrow ? 'All' : 'All Lots',
                count: allCount,
                isSelected: currentTab == 0,
              ),
              _buildFilterTabItem(
                index: 1,
                label: isNarrow ? 'Live' : 'Live Lots',
                count: liveCount,
                isSelected: currentTab == 1,
                hasPulse: liveCount > 0,
                pulseColor: const Color(0xFF10B981),
              ),
              _buildFilterTabItem(
                index: 2,
                label: isNarrow ? 'Upcoming' : 'Upcoming',
                count: upcomingCount,
                isSelected: currentTab == 2,
              ),
              _buildFilterTabItem(
                index: 3,
                label: isNarrow ? 'Ended' : 'Ended',
                count: endedCount,
                isSelected: currentTab == 3,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabItem({
    required int index,
    required String label,
    required int count,
    required bool isSelected,
    bool hasPulse = false,
    Color? pulseColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLotTab = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPulse) ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: pulseColor ?? const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLotsView({
    required int tabIndex,
    required int allCount,
    required int liveCount,
    required int upcomingCount,
    required int endedCount,
  }) {
    String title;
    String subtitle;
    IconData icon;
    String? switchButtonText;
    int? targetTab;

    if (tabIndex == 1) {
      title = 'No Live Lots Right Now';
      subtitle = upcomingCount > 0
          ? 'There are $upcomingCount upcoming lot(s) waiting to go live in this auction event.'
          : 'All lots in this auction event have concluded.';
      icon = Icons.schedule_rounded;
      if (upcomingCount > 0) {
        switchButtonText = 'View Upcoming Lots ($upcomingCount)';
        targetTab = 2;
      } else if (allCount > 0) {
        switchButtonText = 'View All Lots ($allCount)';
        targetTab = 0;
      }
    } else if (tabIndex == 2) {
      title = 'No Upcoming Lots';
      subtitle = liveCount > 0
          ? 'There are $liveCount lot(s) currently live and accepting bids.'
          : 'There are no more upcoming lots scheduled for this auction event.';
      icon = Icons.event_available_rounded;
      if (liveCount > 0) {
        switchButtonText = 'View Live Lots ($liveCount)';
        targetTab = 1;
      }
    } else if (tabIndex == 3) {
      title = 'No Concluded Lots Yet';
      subtitle = 'None of the lots in this auction event have concluded yet.';
      icon = Icons.check_circle_outline_rounded;
      if (liveCount > 0) {
        switchButtonText = 'View Live Lots ($liveCount)';
        targetTab = 1;
      } else {
        switchButtonText = 'View All Lots ($allCount)';
        targetTab = 0;
      }
    } else {
      title = 'No Lots Found';
      subtitle = 'No lots are available for display in this auction event.';
      icon = Icons.inventory_2_outlined;
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF0288D1)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            if (switchButtonText != null && targetTab != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedLotTab = targetTab;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(switchButtonText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLotDetailsDialog(Map item, Map<String, dynamic> state, String displayTitle) {
    final String description = item['description']?.toString() ?? 'No additional description provided.';
    final String location = item['location']?.toString() ?? state['location']?.toString() ?? '';
    final dynamic rawQty = item['quantity'];
    final String unit = item['unit']?.toString() ?? '';
    final double minBid = _parseDouble(state['minBid'], 0.0);
    final double minRaise = _parseDouble(state['minRaise'], 100.0);
    final String catName = (state['category'] ?? state['subcategory'] ?? 'General').toString();
    final images = item['images'];
    final List<String> imgList = (images is List)
        ? images.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : [];
    if (imgList.isEmpty && item['thumbnail_url'] != null) {
      imgList.add(item['thumbnail_url'].toString());
    }

    final String status = state['status']?.toString() ?? 'upcoming';
    final bool dialogEnded = state['auctionEnded'] == true || status == 'ended';
    final bool dialogLive = status == 'live' && !dialogEnded;
    final int dialogTimeRem = _remainingSeconds(state);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Category: $catName',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imgList.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Image.network(
                        imgList.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Quantity', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(formatQuantityWithWords(rawQty ?? '1', unit), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          const Text('Starting Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('₹${_formatCurrency(minBid)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
                        ],
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          const Text('Min Raise', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('+₹${_formatCurrency(minRaise)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          const Text('Time Left', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            dialogEnded ? 'ENDED' : (dialogLive ? _formatTimerDisplay(dialogTimeRem) : 'UPCOMING'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: dialogEnded ? const Color(0xFF64748B) : (dialogLive ? const Color(0xFFDC2626) : const Color(0xFF0288D1)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Location: $location',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Self-contained Lot Card with prominent timer, lot title, item details, and stable controls
  Widget _buildLotCard(String roomId, int index) {
    final state = _roomStates[roomId];
    if (state == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    final item = (state['item'] is Map) ? (state['item'] as Map) : {};
    final String lotTitle = state['title']?.toString() ?? '';
    final String itemName = item['name']?.toString() ?? '';
    final String displayTitle = lotTitle.isNotEmpty ? lotTitle : (itemName.isNotEmpty ? itemName : 'Lot Item');

    final String catName = (state['category'] ?? state['subcategory'] ?? 'Lot').toString().toUpperCase();
    final dynamic rawQty = item['quantity'];
    final String unit = item['unit']?.toString() ?? '';
    final images = item['images'];
    final String? thumbUrl = item['thumbnail_url']?.toString() ??
        (images is List && images.isNotEmpty ? images.first?.toString() : null);

    final double currentBid = _parseDouble(state['currentBid'], 0.0);
    final double minBid = _parseDouble(state['minBid'], 0.0);
    final double minRaise = _parseDouble(state['minRaise'], 100.0);
    final int timeRem = _remainingSeconds(state);
    final bool isHighest = state['isHighestBidder'] == true;
    final bool isFirst = state['isFirstBid'] == true;
    final String status = state['status']?.toString() ?? 'upcoming';
    final bool ended = state['auctionEnded'] == true || status == 'ended';
    final bool isLive = status == 'live' && !ended;
    final bool isUpcoming = status == 'upcoming' && !ended;
    final int extCount = _parseInt(state['extensionCount'], 0);
    final double? winningBid = state['winningBid'] != null ? _parseDouble(state['winningBid'], 0.0) : null;
    final String? winnerAlias = state['winnerAlias']?.toString();
    final String? scheduledStartStr = state['scheduledStart']?.toString();

    final controller = state['bidController'] as TextEditingController? ?? TextEditingController();
    final bool isUrgent = timeRem > 0 && timeRem <= 60 && isLive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighest
              ? const Color(0xFF10B981)
              : (ended ? const Color(0xFFE2E8F0) : (isLive ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE))),
          width: isHighest ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighest
                ? const Color(0xFF10B981).withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header: Lot Number, Category, Details Button & Status Badge ─
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'LOT ${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          catName,
                          style: const TextStyle(color: Color(0xFF0369A1), fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showLotDetailsDialog(item, state, displayTitle),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 11, color: Color(0xFF475569)),
                              SizedBox(width: 3),
                              Text('Details', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Compact Header Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ended
                        ? const Color(0xFFF1F5F9)
                        : (isLive
                            ? (isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5))
                            : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ended
                          ? const Color(0xFFCBD5E1)
                          : (isLive
                              ? (isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0))
                              : const Color(0xFFBFDBFE)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        ended
                            ? 'ENDED'
                            : (isLive ? (isUrgent ? 'LAST MINUTE' : 'LIVE') : 'UPCOMING'),
                        style: TextStyle(
                          color: ended
                              ? const Color(0xFF475569)
                              : (isLive
                                  ? (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF047857))
                                  : const Color(0xFF0284C7)),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Thumbnail & Title ──────────────────────────────────────
          InkWell(
            onTap: () => _showLotDetailsDialog(item, state, displayTitle),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFFF1F5F9),
                      child: thumbUrl != null
                          ? Image.network(
                              thumbUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 28, color: Colors.grey),
                            )
                          : const Icon(Icons.image_outlined, size: 28, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (itemName.isNotEmpty && itemName != displayTitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Item: $itemName',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          'Qty: ${formatQuantityWithWords(rawQty ?? '1', unit)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Big Centered Hero Countdown Timer ──────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: ended
                  ? const Color(0xFFF8FAFC)
                  : (isLive
                      ? (isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4))
                      : const Color(0xFFF0F9FF)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ended
                    ? const Color(0xFFE2E8F0)
                    : (isLive
                        ? (isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E))
                        : const Color(0xFFBAE6FD)),
                width: isUrgent ? 2.0 : 1.2,
              ),
              boxShadow: [
                if (isLive && isUrgent)
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                else if (isLive)
                  BoxShadow(
                    color: const Color(0xFF22C55E).withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ended
                          ? Icons.lock_clock_outlined
                          : (isLive
                              ? (isUrgent ? Icons.warning_amber_rounded : Icons.timer_outlined)
                              : Icons.schedule_rounded),
                      size: 15,
                      color: ended
                          ? const Color(0xFF64748B)
                          : (isLive
                              ? (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                              : const Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ended
                          ? 'AUCTION CONCLUDED'
                          : (isLive
                              ? (isUrgent ? 'URGENT: LAST MINUTE TO BID!' : 'TIME REMAINING')
                              : 'AUCTION STARTS IN'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: ended
                            ? const Color(0xFF64748B)
                            : (isLive
                                ? (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                                : const Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ended
                        ? 'CLOSED'
                        : (isLive
                            ? _formatTimerDisplay(timeRem)
                            : (timeRem > 0 ? _formatTimerDisplay(timeRem) : 'UPCOMING')),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: ended
                          ? const Color(0xFF475569)
                          : (isLive
                              ? (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF0F172A))
                              : const Color(0xFF0369A1)),
                    ),
                  ),
                ),
                if (isLive && extCount > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.more_time_rounded, size: 12, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          'OVERTIME ROUND $extCount (+3 mins added)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isLive && isUrgent) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Bid placed now grants +3 minutes extension',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Price Dashboard Box ────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ended
                      ? 'FINAL WINNING BID'
                      : (isLive ? 'CURRENT HIGHEST BID' : 'STARTING PRICE'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ended
                          ? (winningBid != null && winningBid > 0
                              ? '₹${_formatCurrency(winningBid)}'
                              : (currentBid > 0 ? '₹${_formatCurrency(currentBid)}' : 'Unsold'))
                          : (isLive
                              ? '₹${_formatCurrency(currentBid)}'
                              : '₹${_formatCurrency(minBid)}'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ended ? const Color(0xFF334155) : const Color(0xFF0288D1),
                      ),
                    ),
                    if (isHighest && isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LEADING',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      )
                    else if (isLive && !isFirst)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OUTBID',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLive
                          ? 'Base: ₹${_formatCurrency(minBid)}'
                          : (ended
                              ? (winnerAlias != null && winnerAlias.isNotEmpty ? 'Winner: $winnerAlias' : 'Concluded Lot')
                              : 'Base Price: ₹${_formatCurrency(minBid)}'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isLive
                          ? 'Min Raise: +₹${_formatCurrency(minRaise)}'
                          : (isUpcoming ? 'Min Raise: +₹${_formatCurrency(minRaise)}' : 'Closed'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isLive ? const Color(0xFFD97706) : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Status Banner (Highest Bidder in Green & Losing Bidders in Red) ──
          if (isLive && isHighest)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are the highest bidder',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF14532D),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isLive && !isFirst)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are not the highest bidder',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF7F1D1D),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isLive && isFirst && minBid > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '1st Bid Max: ₹${_formatCurrency(minBid * 10)} (10x Base)',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (isUpcoming)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scheduledStartStr != null && scheduledStartStr.isNotEmpty
                          ? 'Starts: ${DateTimeUtils.formatIST(DateTime.tryParse(scheduledStartStr) ?? DateTime.now())}'
                          : 'Waiting Room • Starts Soon',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Quick Increment Buttons (Only for Live Lots) ───────────
          if (isLive && !_isSpectator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Row(
                children: [
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + minRaise,
                    '+₹${_formatCurrency(minRaise)}',
                    enabled: !isHighest,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + (minRaise * 5),
                    '+₹${_formatCurrency(minRaise * 5)}',
                    enabled: !isHighest,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + (minRaise * 10),
                    '+₹${_formatCurrency(minRaise * 10)}',
                    enabled: !isHighest,
                  ),
                ],
              ),
            ),

          // ── Action Area (Live: Bidding Input, Upcoming: Waiting Room, Ended: Concluded) ──
          if (isLive && !_isSpectator)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !isHighest,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: isHighest ? 'Leading this lot' : 'Next: ₹${_formatCurrency(currentBid + minRaise)}',
                        prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isHighest ? null : () => _placeBidForRoom(roomId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0288D1),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                    child: Text(
                      isHighest ? 'Leading' : 'Bid Now',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isHighest ? const Color(0xFF64748B) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isUpcoming)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 15, color: Color(0xFF0288D1)),
                  SizedBox(width: 6),
                  Text(
                    'Waiting Room • Starts Soon',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                  ),
                ],
              ),
            )
          else if (ended)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Auction Lot Concluded',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickIncrementBtn(String roomId, double targetAmount, String label, {bool enabled = true}) {
    final state = _roomStates[roomId];
    final controller = state?['bidController'] as TextEditingController?;
    return Expanded(
      child: OutlinedButton(
        onPressed: enabled
            ? () {
                final rounded = double.parse(targetAmount.toStringAsFixed(2));
                if (controller != null) {
                  controller.text = _formatCurrency(rounded);
                }
                _placeBidForRoom(roomId, rounded);
              }
            : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: enabled ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 7),
          backgroundColor: enabled ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: enabled ? const Color(0xFF0288D1) : const Color(0xFF94A3B8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_groupTitle ?? widget.roomTitle),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.gavel_rounded, size: 64, color: Color(0xFF0288D1)),
                const SizedBox(height: 20),
                Text(
                  _groupTitle ?? widget.roomTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your approved credentials to join live group bidding.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _tempEmailController,
                  onChanged: (_) {
                    if (_loginErrorMessage != null) setState(() => _loginErrorMessage = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Bidder Email / ID',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tempPasswordController,
                  onChanged: (_) {
                    if (_loginErrorMessage != null) setState(() => _loginErrorMessage = null);
                  },
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _performEphemeralLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enter Live Bidding Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                if (_loginErrorMessage != null && _loginErrorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _loginErrorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
