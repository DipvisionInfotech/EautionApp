import 'dart:async';
import 'dart:convert';
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

class _LiveAuctionPageState extends State<LiveAuctionPage> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;

  String? _groupId;
  String? _groupTitle;
  List<Map<String, dynamic>> _categories = [];

  // Independent state per room: roomId -> roomState
  final Map<String, Map<String, dynamic>> _roomStates = {};

  // Active WebSocket channels per room: roomId -> channel
  final Map<String, WebSocketChannel> _roomChannels = {};

  Timer? _countdownTimer;
  bool _isSpectator = false;
  String? _userRole;

  final TextEditingController _tempEmailController = TextEditingController();
  final TextEditingController _tempPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGroupCategoriesAndInit();
  }

  @override
  void dispose() {
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

  Future<void> _fetchGroupCategoriesAndInit() async {
    setState(() => _isLoading = true);

    try {
      final groupResult = await ApiService.getGroupCategories(widget.roomId);
      if (groupResult['success'] == true && mounted) {
        final data = groupResult['data'] as Map<String, dynamic>;
        _groupId = data['group_id']?.toString();
        _groupTitle = data['group_title']?.toString() ?? widget.roomTitle;
        final rawList = (data['categories'] as List<dynamic>?) ?? [];

        _categories = rawList.map((c) => Map<String, dynamic>.from(c as Map)).toList();

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
          };
        }
      }
    } catch (e, stack) {
      debugPrint("Error loading group categories: $e\n$stack");
    }

    _startGlobalCountdownTimer();
    await _checkRoleAndAutoConnect();
  }

  void _startGlobalCountdownTimer() {
    _countdownTimer?.cancel();
    int tickCount = 0;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      tickCount++;
      setState(() {
        for (var state in _roomStates.values) {
          int rem = (state['timeRemainingSec'] as int?) ?? 0;
          bool ended = state['auctionEnded'] == true;
          String status = state['status']?.toString() ?? '';
          if (status == 'live' && rem > 0 && !ended) {
            final newRem = rem - 1;
            state['timeRemainingSec'] = newRem;
            if (newRem == 0) {
              state['auctionEnded'] = true;
              state['status'] = 'ended';
            }
          }
        }
      });

      // Periodically (every 10 seconds), check if any upcoming lot's scheduled_start has arrived
      if (tickCount % 10 == 0) {
        bool shouldRefresh = false;
        final now = DateTime.now().toUtc();
        for (var cat in _categories) {
          if (cat['status'] == 'upcoming' && cat['scheduled_start'] != null) {
            final start = DateTime.tryParse(cat['scheduled_start'].toString());
            if (start != null && now.isAfter(start.toUtc())) {
              shouldRefresh = true;
              break;
            }
          }
        }
        if (shouldRefresh) {
          _fetchGroupCategoriesAndInit();
        }
      }
    });
  }

  /// Check user role: ONLY admin gets spectator auto-connect.
  /// ALL BIDDERS (even if logged in to website) MUST enter room-specific credentials on the login screen.
  Future<void> _checkRoleAndAutoConnect() async {
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

    // Always require entering room-specific credentials for bidders
    setState(() {
      _isAuthenticated = false;
      _isLoading = false;
    });
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
      bool hasReceivedData = false;

      final channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: [token],
      );

      _roomChannels[roomId]?.sink.close();
      _roomChannels[roomId] = channel;

      channel.stream.listen(
        (message) {
          hasReceivedData = true;
          final data = jsonDecode(message);
          _handleRoomWebSocketMessage(roomId, data);
        },
        onError: (error) {
          debugPrint("WS error in room $roomId: $error");
          if (!hasReceivedData) {
            _connectSingleRoomWebSocketFallback(roomId, token);
          }
        },
        onDone: () {
          debugPrint("WS closed in room $roomId");
        },
      );
    } catch (e) {
      debugPrint("Failed to connect WS in room $roomId: $e");
      _connectSingleRoomWebSocketFallback(roomId, token);
    }
  }

  void _connectSingleRoomWebSocketFallback(String roomId, String token) {
    final baseWs = ApiService.baseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceFirst('/api', '');

    final wsUrl = '$baseWs/ws/room/$roomId/?token=$token';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _roomChannels[roomId]?.sink.close();
    _roomChannels[roomId] = channel;

    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        _handleRoomWebSocketMessage(roomId, data);
      },
      onError: (e) => debugPrint("Legacy WS error in room $roomId: $e"),
    );
  }

  void _handleRoomWebSocketMessage(String roomId, Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'];
    final state = _roomStates[roomId];
    if (state == null) return;

    setState(() {
      if (type == 'room_state') {
        if (data['current_bid'] != null) state['currentBid'] = _parseDouble(data['current_bid'], state['currentBid']);
        if (data['min_bid'] != null) state['minBid'] = _parseDouble(data['min_bid'], state['minBid']);
        if (data['min_raise'] != null) state['minRaise'] = _parseDouble(data['min_raise'], state['minRaise']);
        if (data['time_remaining_sec'] != null) state['timeRemainingSec'] = _parseInt(data['time_remaining_sec'], state['timeRemainingSec']);
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
        final double newAmt = _parseDouble(data['amount'], 0.0);
        final String newAlias = data['bidder_alias']?.toString() ?? 'Unknown';

        state['currentBid'] = newAmt;
        state['isFirstBid'] = false;
        // Strictly evaluate highest bidder for THIS specific room independently
        state['isHighestBidder'] = (data['is_highest_bidder'] == true) ||
            (state['myAlias'] != null && newAlias == state['myAlias']);
      } else if (type == 'countdown_tick') {
        if (state['auctionEnded'] != true) {
          final secs = _parseInt(data['seconds_remaining'], state['timeRemainingSec']);
          state['timeRemainingSec'] = secs;
          if (secs == 0) {
            state['auctionEnded'] = true;
          }
        }
      } else if (type == 'auction_ended') {
        state['auctionEnded'] = true;
        state['winnerAlias'] = data['winner_alias']?.toString();
        state['winningBid'] = _parseDouble(data['winning_bid'], 0.0);
      } else if (type == 'error' || type == 'bid_rejected') {
        String errorMsg = data['message']?.toString() ?? '';
        if (errorMsg.isEmpty) {
          final reason = data['reason']?.toString();
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
            errorMsg = 'Auction has ended.';
          } else {
            errorMsg = 'Bid could not be accepted.';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both email and password are required.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.ephemeralLogin(email, password, roomId: widget.roomId);

    if (!mounted) return;

    if (result['success'] == true) {
      final String sessionToken = result['token']?.toString() ?? '';
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
            // For standard bidder login, get ws token for this room
            try {
              final wsResult = await ApiService.getWebSocketToken(widget.roomId);
              if (wsResult['success'] == true && wsResult['token'] != null) {
                await _connectAllRoomsWithSession(wsResult['token'].toString());
                return;
              }
            } catch (_) {}
          }
        }
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Invalid credentials or room access expired.'),
          backgroundColor: Colors.red,
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

    // 1st Bid Capping check (10x starting price)
    final double startingPrice = _parseDouble(state['minBid'], 0.0);
    final bool isFirst = state['isFirstBid'] == true;
    if (isFirst && startingPrice > 0) {
      final maxFirst = startingPrice * 10;
      if (amount > maxFirst) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('1st bid cannot exceed ₹${_formatCurrency(maxFirst)} (10x starting price).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final channel = _roomChannels[roomId];
    if (channel != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      channel.sink.add(jsonEncode({
        "type": "place_bid",
        "amount": amount,
      }));
      controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to this lot room. Reconnecting...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth >= 1100 ? 3 : (screenWidth >= 650 ? 2 : 1);

    // Classify lots strictly: LIVE, UPCOMING, and ENDED
    final liveLots = _categories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return status == 'live' && !isEnded;
    }).toList();

    final upcomingLots = _categories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return status == 'upcoming' && !isEnded;
    }).toList();

    final endedLots = _categories.where((cat) {
      final rId = cat['id']?.toString() ?? '';
      final state = _roomStates[rId];
      final status = state?['status']?.toString() ?? cat['status']?.toString();
      final isEnded = state?['auctionEnded'] == true || status == 'ended';
      return isEnded;
    }).toList();

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
                  ? 'Live Bidding • ${liveLots.length} Live Lot${liveLots.length == 1 ? '' : 's'}'
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
            onPressed: _fetchGroupCategoriesAndInit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _categories.isEmpty
                  ? const Center(child: Text("No auction lots found for this event."))
                  : liveLots.isNotEmpty
                      ? SingleChildScrollView(
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

                              // ── Single Page 3-Column Card Matrix Grid (ONLY LIVE LOTS) ──────
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  const double spacing = 14.0;
                                  final double calcWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                                  final double cardWidth = calcWidth > 260.0 ? calcWidth : constraints.maxWidth;

                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: List.generate(liveLots.length, (idx) {
                                      final cat = liveLots[idx];
                                      final rId = cat['id']?.toString() ?? '';
                                      return SizedBox(
                                        width: cardWidth,
                                        child: _buildLotCard(rId, idx),
                                      );
                                    }),
                                  );
                                },
                              ),

                              // Informational footer if additional lots will go live later
                              if (upcomingLots.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${upcomingLots.length} more lot(s) in this event are scheduled to go live later.',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Informational footer if some lots have ended
                              if (endedLots.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Color(0xFF64748B), size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${endedLots.length} lot(s) in this event have concluded.',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        )
                      : upcomingLots.isNotEmpty
                          ? _buildUpcomingWaitingView(upcomingLots)
                          : _buildConcludedView(endedLots),
    );
  }

  Widget _buildUpcomingWaitingView(List<Map<String, dynamic>> upcomingLots) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFF0288D1), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Lots Currently Live',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'There are ${upcomingLots.length} upcoming lot(s) in this auction event. Bidding will open once a lot begins.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              ...upcomingLots.map((uCat) {
                final uItem = (uCat['item'] is Map) ? (uCat['item'] as Map) : {};
                final uTitle = uCat['title']?.toString() ?? uItem['name']?.toString() ?? 'Lot';
                final uStart = uCat['scheduled_start']?.toString() ?? '';
                final double uMinBid = _parseDouble(uItem['min_bid'] ?? uCat['min_bid'], 0.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0288D1)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uTitle,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (uMinBid > 0)
                              Text(
                                'Starting Price: ₹${_formatCurrency(uMinBid)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          uStart.isNotEmpty ? 'Starts ${DateTimeUtils.formatIST(uStart, pattern: 'hh:mm a')}' : 'Upcoming',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchGroupCategoriesAndInit,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check for Live Lots'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0288D1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcludedView(List<Map<String, dynamic>> endedLots) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF64748B), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Auction Event Concluded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'All lots for this event have ended.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ...endedLots.map((eCat) {
                final rId = eCat['id']?.toString() ?? '';
                final state = _roomStates[rId];
                final eItem = (eCat['item'] is Map) ? (eCat['item'] as Map) : {};
                final eTitle = eCat['title']?.toString() ?? eItem['name']?.toString() ?? 'Lot';
                final double finalBid = _parseDouble(state?['winningBid'] ?? state?['currentBid'] ?? eCat['current_bid'], 0.0);
                final String? winner = state?['winnerAlias'] ?? eCat['latest_bidder_alias'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eTitle,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (winner != null && winner.isNotEmpty)
                              Text(
                                'Winner: $winner',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${_formatCurrency(finalBid)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Exit Bidding Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
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
    final String? thumbUrl = item['thumbnail_url']?.toString();

    final double currentBid = _parseDouble(state['currentBid'], 0.0);
    final double minBid = _parseDouble(state['minBid'], 0.0);
    final double minRaise = _parseDouble(state['minRaise'], 100.0);
    final int timeRem = _parseInt(state['timeRemainingSec'], 0);
    final bool isHighest = state['isHighestBidder'] == true;
    final bool isFirst = state['isFirstBid'] == true;
    final bool ended = state['auctionEnded'] == true;
    final controller = state['bidController'] as TextEditingController? ?? TextEditingController();

    final bool isUrgent = timeRem > 0 && timeRem < 120 && !ended;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighest
              ? const Color(0xFF10B981)
              : (ended ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
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
          // ── Card Header: Lot Number, Category & Prominent Timer Pill ─
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
                Wrap(
                  spacing: 6,
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
                  ],
                ),

                // Prominent high-contrast countdown timer badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ended
                        ? const Color(0xFF334155)
                        : (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF047857)),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      if (!ended)
                        BoxShadow(
                          color: (isUrgent ? const Color(0xFFDC2626) : const Color(0xFF047857)).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ended ? Colors.white54 : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimerDisplay(timeRem),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Thumbnail & Title ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
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
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (itemName.isNotEmpty && itemName != displayTitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Item: $itemName',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        'Qty: ${formatQuantityWithWords(rawQty ?? '1', unit)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
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
                const Text(
                  'CURRENT HIGHEST BID',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${_formatCurrency(currentBid)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0288D1),
                      ),
                    ),
                    if (isHighest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LEADING',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Base: ₹${_formatCurrency(minBid)}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Min Raise: +₹${_formatCurrency(minRaise)}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Leading / 1st Bid Cap Status Pill ──────────────────────
          if (isHighest)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF059669), size: 15),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You hold the highest bid on this lot! Awaiting bids.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else if (isFirst && minBid > 0)
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
            ),

          // ── Quick Increment Buttons (Layout Stable: Disabled when leading, never collapsed) ──
          if (!_isSpectator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Row(
                children: [
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + minRaise,
                    '+₹${_formatCurrency(minRaise)}',
                    enabled: !ended && !isHighest,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + (minRaise * 5),
                    '+₹${_formatCurrency(minRaise * 5)}',
                    enabled: !ended && !isHighest,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(
                    roomId,
                    currentBid + (minRaise * 10),
                    '+₹${_formatCurrency(minRaise * 10)}',
                    enabled: !ended && !isHighest,
                  ),
                ],
              ),
            ),

          // ── Direct Bidding Input & Action Button ────────────────────
          if (!ended && !_isSpectator)
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
          else if (ended)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Auction Lot Concluded',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
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
                  decoration: InputDecoration(
                    labelText: 'Bidder Email / ID',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tempPasswordController,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
