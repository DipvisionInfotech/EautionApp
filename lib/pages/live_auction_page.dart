import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../utils/number_to_words.dart';

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
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isSpectator = false; // True for admin/seller role
  String? _errorMessage;
  String? _userRole;
  Timer? _countdownTimer;

  // Group Auction State
  String? _groupId;
  String? _groupTitle;
  List<Map<String, dynamic>> _categories = [];
  final Map<String, Map<String, dynamic>> _roomStates = {};
  final Map<String, WebSocketChannel> _roomChannels = {};

  // Auth Inputs for Unauthenticated / Ephemeral fallback
  final TextEditingController _tempEmailController = TextEditingController();
  final TextEditingController _tempPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGroupCategoriesAndInit();
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

        // Initialize independent state for each category room
        for (var cat in _categories) {
          final rId = cat['id']?.toString() ?? '';
          if (rId.isEmpty) continue;

          final minBid = (cat['item']?['min_bid'] as num?)?.toDouble() ?? 0.0;
          final minRaise = (cat['item']?['min_raise'] as num?)?.toDouble() ?? 100.0;
          final currentBid = (cat['current_bid'] as num?)?.toDouble() ?? minBid;
          final timeRem = (cat['time_remaining_sec'] as num?)?.toInt() ?? 0;

          _roomStates[rId] = {
            'roomId': rId,
            'title': cat['title'] ?? '',
            'category': cat['category'] ?? '',
            'subcategory': cat['subcategory'] ?? '',
            'item': cat['item'] ?? {},
            'currentBid': currentBid,
            'minBid': minBid,
            'minRaise': minRaise,
            'timeRemainingSec': timeRem,
            'isHighestBidder': false,
            'isFirstBid': (cat['bids_count'] ?? 0) == 0,
            'auctionEnded': cat['status'] == 'ended',
            'winnerAlias': cat['winner']?['user_id'],
            'winningBid': (cat['winner']?['bid_amount'] as num?)?.toDouble(),
            'myAlias': null,
            'bidController': TextEditingController(),
            'isSpectator': false,
          };
        }
      }
    } catch (e) {
      debugPrint("Error loading group categories: $e");
    }

    _startGlobalCountdownTimer();
    await _checkRoleAndAutoConnect();
  }

  void _startGlobalCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        for (var state in _roomStates.values) {
          int rem = (state['timeRemainingSec'] as int?) ?? 0;
          bool ended = state['auctionEnded'] == true;
          if (rem > 0 && !ended) {
            final newRem = rem - 1;
            state['timeRemainingSec'] = newRem;
            if (newRem == 0) {
              state['auctionEnded'] = true;
            }
          }
        }
      });
    });
  }

  /// Check if the currently logged-in user is authenticated and connect all authorized lot rooms
  Future<void> _checkRoleAndAutoConnect() async {
    final profileResult = await ApiService.getProfile();

    if (!mounted) return;

    if (profileResult['success'] == true) {
      final role = profileResult['data']?['role'] as String?;
      _userRole = role;

      if (role == 'admin' || role == 'seller' || role == 'test_bidder' || role == 'bidder') {
        await _connectAllRoomsForCurrentUser();
        return;
      }
    }

    // Unauthenticated visitor — show login screen
    setState(() => _isLoading = false);
  }

  /// Connect all group category rooms that the current user has access to
  Future<void> _connectAllRoomsForCurrentUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      setState(() => _isAuthenticated = true);

      // Connect each room's WebSocket independently
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        if (rId.isEmpty) continue;

        try {
          final tokenResult = await ApiService.getWebSocketToken(rId);
          if (tokenResult['success'] == true && tokenResult['token'] != null) {
            _connectSingleRoomWebSocket(rId, tokenResult['token']);
          }
        } catch (e) {
          debugPrint("Could not connect WS for room $rId: $e");
        }
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
        protocols: ['token', token],
      );

      _roomChannels[roomId] = channel;

      channel.stream.listen(
        (message) {
          hasReceivedData = true;
          final data = jsonDecode(message);
          _handleRoomWebSocketMessage(roomId, data);
        },
        onError: (error) {
          if (!hasReceivedData && mounted) {
            _connectSingleRoomWebSocketFallback(roomId, baseWs, token);
          }
        },
        onDone: () {
          if (!hasReceivedData && mounted) {
            _connectSingleRoomWebSocketFallback(roomId, baseWs, token);
          }
        },
      );
    } catch (e) {
      debugPrint("WS error connecting to room $roomId: $e");
    }
  }

  void _connectSingleRoomWebSocketFallback(String roomId, String baseWs, String token) {
    if (!mounted) return;
    final wsUrlLegacy = '$baseWs/ws/room/$roomId/?token=$token';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrlLegacy));
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
        state['currentBid'] = (data['current_bid'] as num?)?.toDouble() ?? state['currentBid'];
        state['minBid'] = (data['min_bid'] as num?)?.toDouble() ?? state['minBid'];
        state['minRaise'] = (data['min_raise'] as num?)?.toDouble() ?? state['minRaise'];
        state['timeRemainingSec'] = (data['time_remaining_sec'] as num?)?.toInt() ?? state['timeRemainingSec'];
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
        final double newAmt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final String newAlias = data['bidder_alias']?.toString() ?? 'Unknown';

        state['currentBid'] = newAmt;
        state['isFirstBid'] = false;
        // Strictly evaluate highest bidder for THIS specific room independently
        state['isHighestBidder'] = (data['is_highest_bidder'] == true) ||
            (state['myAlias'] != null && newAlias == state['myAlias']);
      } else if (type == 'countdown_tick') {
        if (state['auctionEnded'] != true) {
          final secs = (data['seconds_remaining'] as num?)?.toInt() ?? state['timeRemainingSec'];
          state['timeRemainingSec'] = secs;
          if (secs == 0) {
            state['auctionEnded'] = true;
          }
        }
      } else if (type == 'auction_ended') {
        state['auctionEnded'] = true;
        state['winnerAlias'] = data['winner_alias']?.toString();
        state['winningBid'] = (data['winning_bid'] as num?)?.toDouble();
      } else if (type == 'error' || type == 'bid_rejected') {
        String errorMsg = data['message']?.toString() ?? '';
        if (errorMsg.isEmpty) {
          final reason = data['reason']?.toString();
          if (reason == 'self_outbid_restricted') {
            errorMsg = 'You are already the highest bidder on this lot.';
          } else if (reason == 'first_bid_cap_exceeded') {
            final maxFirst = data['max_first_bid'];
            errorMsg = maxFirst != null
                ? 'The 1st bid cannot exceed ₹${_formatCurrency(maxFirst as num)} (10x starting price).'
                : '1st bid cannot exceed 10x starting price.';
          } else if (reason == 'below_minimum') {
            final minNext = data['min_next_bid'];
            errorMsg = minNext != null
                ? 'Bid must be at least ₹${_formatCurrency(minNext as num)}.'
                : 'Bid is below minimum required raise.';
          } else if (reason == 'auction_ended') {
            errorMsg = 'This auction lot has ended.';
          } else {
            errorMsg = reason ?? 'Error placing bid';
          }
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  String _formatCurrency(num amount) {
    String str = amount.toStringAsFixed(2);
    final rawStr = amount.toString();
    if (rawStr.contains('.')) {
      final decPart = rawStr.split('.')[1];
      if (decPart.length > 2) {
        str = amount.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
        if (str.endsWith('.')) str += '00';
      }
    }
    final parts = str.split('.');
    final whole = parts[0];
    final dec = parts.length > 1 ? parts[1] : '00';
    final regex = RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))');
    final formattedWhole = whole.replaceAllMapped(regex, (match) => '${match[1]},');
    return '$formattedWhole.$dec';
  }

  String _formatTimerDisplay(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0) {
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

    if (result['success'] == true) {
      setState(() => _isAuthenticated = true);
      await _connectAllRoomsForCurrentUser();
    } else {
      // If user might be entering standard account credentials
      if (!email.contains('@auction.internal')) {
        final standardResult = await ApiService.login(email, password);
        if (standardResult['success'] == true) {
          await _connectAllRoomsForCurrentUser();
          return;
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

    final double currentBid = (state['currentBid'] as num?)?.toDouble() ?? 0.0;
    if (amount == null || amount <= currentBid) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid must be higher than current bid (₹${_formatCurrency(currentBid)})')),
      );
      return;
    }

    // 1st Bid Capping check (10x starting price)
    final double startingPrice = (state['minBid'] as num?)?.toDouble() ?? 0.0;
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
        'type': 'place_bid',
        'amount': amount,
      }));
      controller.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting to this lot... Please wait a second and retry.')),
      );
      // Attempt reconnection in background
      ApiService.getWebSocketToken(roomId).then((res) {
        if (res['success'] == true && res['token'] != null) {
          _connectSingleRoomWebSocket(roomId, res['token']);
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var ch in _roomChannels.values) {
      ch.sink.close();
    }
    for (var st in _roomStates.values) {
      (st['bidController'] as TextEditingController?)?.dispose();
    }
    _tempEmailController.dispose();
    _tempPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isAuthenticated) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_groupTitle ?? widget.roomTitle),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0288D1))),
      );
    }

    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groupTitle ?? widget.roomTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Live Bidding • ${_categories.length} Lot${_categories.length > 1 ? "s" : ""} Available',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0288D1), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_isSpectator)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 14, color: Color(0xFF2E7D32)),
                  SizedBox(width: 4),
                  Text('Spectator Mode', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 54, color: Colors.red),
                    const SizedBox(height: 14),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spectator Banner
                  if (_isSpectator)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Spectator Mode — Real-time group auction monitoring. Bidding is disabled.',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Responsive 3-Column Card Matrix Grid on Single Page ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      // Max 3 cards per row on desktop/wide screen, 2 on medium, 1 on mobile
                      final int columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
                      const double spacing = 16.0;
                      final double cardWidth = (width - (spacing * (columns - 1))) / columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(_categories.length, (idx) {
                          final cat = _categories[idx];
                          final rId = cat['id']?.toString() ?? '';
                          return SizedBox(
                            width: cardWidth,
                            child: _buildLotLiveCard(rId, idx),
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

  /// Self-contained live bidding card with prominent timer, independent locking, and instant updates
  Widget _buildLotLiveCard(String roomId, int lotIndex) {
    final state = _roomStates[roomId];
    if (state == null) return const SizedBox.shrink();

    final item = state['item'] as Map<String, dynamic>? ?? {};
    final String catName = (state['category'] ?? state['subcategory'] ?? 'Lot').toString().toUpperCase();
    final String itemName = item['name'] ?? state['title'] ?? 'Lot Item';
    final double currentBid = (state['currentBid'] as num?)?.toDouble() ?? 0.0;
    final double minBid = (state['minBid'] as num?)?.toDouble() ?? 0.0;
    final double minRaise = (state['minRaise'] as num?)?.toDouble() ?? 100.0;
    final int timeRem = (state['timeRemainingSec'] as int?) ?? 0;
    final bool isHighest = state['isHighestBidder'] == true;
    final bool isFirst = state['isFirstBid'] == true;
    final bool ended = state['auctionEnded'] == true;
    final controller = state['bidController'] as TextEditingController;

    final List images = item['images'] is List ? item['images'] as List : [];
    final String? thumbUrl = images.isNotEmpty ? images[0].toString() : null;
    final String qty = item['quantity']?.toString() ?? '1';
    final String unit = item['unit']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighest
              ? const Color(0xFF10B981)
              : (ended ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
          width: isHighest ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighest
                ? const Color(0xFF10B981).withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Top Header: Badges & PROMINENT BIG TIMER ──────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isHighest ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: isHighest ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lot Badge + Category
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LOT ${lotIndex + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        catName,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                      ),
                    ),
                  ],
                ),

                // ── Big Prominent Countdown Timer ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ended
                        ? const Color(0xFF334155)
                        : (timeRem < 120 ? const Color(0xFFDC2626) : const Color(0xFF047857)),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      if (!ended)
                        BoxShadow(
                          color: (timeRem < 120 ? Colors.red : Colors.green).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!ended) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        ended ? 'ENDED' : _formatTimerDisplay(timeRem),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Item Title & Thumbnail Row ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 64,
                    height: 64,
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
                        itemName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${formatQuantityWithWords(qty, unit)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Price Dashboard Box ────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

          // ── Quick Increment Buttons ────────────────────────────────
          if (!ended && !_isSpectator && !isHighest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  _buildQuickIncrementBtn(roomId, currentBid + minRaise, '+₹${_formatCurrency(minRaise)}'),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(roomId, currentBid + (minRaise * 5), '+₹${_formatCurrency(minRaise * 5)}'),
                  const SizedBox(width: 6),
                  _buildQuickIncrementBtn(roomId, currentBid + (minRaise * 10), '+₹${_formatCurrency(minRaise * 10)}'),
                ],
              ),
            ),

          // ── Direct Bidding Input & Action Button ────────────────────
          if (!ended && !_isSpectator)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
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

  Widget _buildQuickIncrementBtn(String roomId, double targetAmount, String label) {
    final state = _roomStates[roomId];
    final controller = state?['bidController'] as TextEditingController?;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          final rounded = double.parse(targetAmount.toStringAsFixed(2));
          if (controller != null) {
            controller.text = _formatCurrency(rounded);
          }
          _placeBidForRoom(roomId, rounded);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFBAE6FD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 7),
          backgroundColor: const Color(0xFFF0F9FF),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
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
