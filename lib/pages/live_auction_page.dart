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
  bool _isSpectator = false;      // True for admin role → read-only mode
  String? _errorMessage;
  String? _userRole;              // Cached role for this session
  Timer? _countdownTimer;

  // Group Auction State
  String? _groupId;
  String? _groupTitle;
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategoryRoomId = ''; // '' or 'all' means "All Categories"
  final Map<String, Map<String, dynamic>> _roomStates = {};
  final Map<String, WebSocketChannel> _roomChannels = {};

  // Auth Inputs
  final TextEditingController _tempEmailController = TextEditingController();
  final TextEditingController _tempPasswordController = TextEditingController();
  String? _authenticatedUserAlias;

  @override
  void initState() {
    super.initState();
    _selectedCategoryRoomId = widget.roomId;
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

        // Initialize state for each category room
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
            'bidderCount': cat['bidder_count'] ?? 0,
            'isHighestBidder': false,
            'isFirstBid': (cat['bids_count'] ?? 0) == 0,
            'auctionEnded': cat['status'] == 'ended',
            'winnerAlias': cat['winner']?['user_id'],
            'winningBid': (cat['winner']?['bid_amount'] as num?)?.toDouble(),
            'bidHistory': <Map<String, dynamic>>[],
            'bidController': TextEditingController(),
            'isSpectator': false,
            'isExpanded': false,
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
            state['timeRemainingSec'] = rem - 1;
          }
        }
      });
    });
  }

  /// Check if the currently logged-in user is admin or test_bidder.
  Future<void> _checkRoleAndAutoConnect() async {
    final profileResult = await ApiService.getProfile();

    if (!mounted) return;

    if (profileResult['success'] == true) {
      final role = profileResult['data']?['role'] as String?;
      _userRole = role;

      if (role == 'admin' || role == 'seller' || role == 'test_bidder') {
        await _connectAllRoomsAsPrivileged();
        return;
      }
    }

    // Regular bidder — show credentials form
    setState(() => _isLoading = false);
  }

  /// Connect all group category rooms via JWT token
  Future<void> _connectAllRoomsAsPrivileged() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      setState(() => _isAuthenticated = true);

      // Connect each room's WebSocket
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        if (rId.isEmpty) continue;

        final tokenResult = await ApiService.getWebSocketToken(rId);
        if (tokenResult['success'] == true) {
          _connectSingleRoomWebSocket(rId, tokenResult['token']);
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
        state['bidderCount'] = (data['bidder_count'] as num?)?.toInt() ?? state['bidderCount'];
        state['timeRemainingSec'] = (data['time_remaining_sec'] as num?)?.toInt() ?? state['timeRemainingSec'];
        state['isHighestBidder'] = data['is_highest_bidder'] == true;
        state['isFirstBid'] = data['is_first_bid'] == true;

        if (data['bidder_alias'] != null) {
          _authenticatedUserAlias = data['bidder_alias'].toString();
        }

        if (data['is_spectator'] == true) {
          _isSpectator = true;
          state['isSpectator'] = true;
        }

        if (data['bids'] != null) {
          final historyList = <Map<String, dynamic>>[];
          for (var b in data['bids']) {
            historyList.add({
              'alias': b['bidder_alias']?.toString() ?? 'Unknown',
              'amount': (b['amount'] as num?)?.toDouble() ?? 0.0,
              'time': DateTimeUtils.parseUtc(b['timestamp']?.toString()),
            });
          }
          state['bidHistory'] = historyList;
          if (historyList.isNotEmpty) {
            state['isFirstBid'] = false;
          }
        }
      } 
      else if (type == 'new_bid') {
        final double newAmt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final String newAlias = data['bidder_alias']?.toString() ?? 'Unknown';
        final bool wasLeading = state['isHighestBidder'] == true;

        state['currentBid'] = newAmt;
        state['isFirstBid'] = false;
        state['isHighestBidder'] = (_authenticatedUserAlias != null && newAlias == _authenticatedUserAlias);

        final historyList = (state['bidHistory'] as List<Map<String, dynamic>>?) ?? [];
        historyList.insert(0, {
          'alias': newAlias,
          'amount': newAmt,
          'time': DateTimeUtils.parseUtc(data['timestamp']?.toString()),
        });
        state['bidHistory'] = historyList;

        // Trigger an Outbid Alert Toast if the user was leading on this category and just got topped
        if (wasLeading && !state['isHighestBidder']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFC62828),
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ Outbid Alert! Someone bid ₹${_formatCurrency(newAmt)} on Category: ${state['category'] ?? state['title']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.amber,
                onPressed: () {
                  setState(() => _selectedCategoryRoomId = roomId);
                },
              ),
            ),
          );
        }
      } 
      else if (type == 'countdown_tick') {
        state['timeRemainingSec'] = (data['seconds_remaining'] as num?)?.toInt() ?? state['timeRemainingSec'];
      } 
      else if (type == 'auction_ended') {
        state['auctionEnded'] = true;
        state['winnerAlias'] = data['winner_alias']?.toString();
        state['winningBid'] = (data['winning_bid'] as num?)?.toDouble();
      } 
      else if (type == 'error' || type == 'bid_rejected') {
        String errorMsg = data['message']?.toString() ?? '';
        if (errorMsg.isEmpty) {
          final reason = data['reason']?.toString();
          if (reason == 'self_outbid_restricted') {
            errorMsg = 'You are already the highest bidder. You cannot bid against yourself.';
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
            errorMsg = 'This auction category has ended.';
          } else {
            errorMsg = reason ?? 'Error placing bid';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('[$roomId] $errorMsg'), backgroundColor: Colors.red),
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

  String _formatTime(int seconds) {
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
      final sessionRoomId = result['roomId']?.toString() ?? '';

      // Check if session room matches the current room or one of group categories
      final bool isAllowed = sessionRoomId == widget.roomId ||
          _categories.any((c) => c['id']?.toString() == sessionRoomId);

      if (!isAllowed) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('These credentials are not authorized for this auction room.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isAuthenticated = true);

      // Connect WebSocket ONLY for the authorized category room
      for (var cat in _categories) {
        final rId = cat['id']?.toString() ?? '';
        if (rId == sessionRoomId || (sessionRoomId.isEmpty && rId == widget.roomId)) {
          _connectSingleRoomWebSocket(rId, result['token']);
        }
      }
    } else {
      // If error was 403 or specific auth error, display it immediately
      final dynamic rawError = result['error'];
      String errorMsg = '';
      if (rawError is Map && rawError['error'] != null) {
        errorMsg = rawError['error'].toString();
      } else if (rawError is String) {
        errorMsg = rawError;
      }

      // If user might be an admin/seller entering standard account credentials
      if (!email.contains('@auction.internal')) {
        final standardResult = await ApiService.login(email, password);
        if (standardResult['success'] == true) {
          await _connectAllRoomsAsPrivileged();
          return;
        }
      }

      setState(() => _isLoading = false);
      if (errorMsg.isEmpty) {
        errorMsg = 'Invalid credentials or room access expired.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  void _placeBidForRoom(String roomId, [double? presetAmount]) {
    final state = _roomStates[roomId];
    if (state == null) return;

    if (_isSpectator || state['isSpectator'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are in spectator/admin mode. Bidding is disabled.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (state['isHighestBidder'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You currently hold the highest bid. Cannot outbid yourself.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final controller = state['bidController'] as TextEditingController;
    double? amount = presetAmount;
    if (amount == null) {
      if (controller.text.isEmpty) return;
      amount = double.tryParse(controller.text.trim());
    }

    if (amount != null) {
      amount = double.parse(amount.toStringAsFixed(2));
    }

    final double currentBid = (state['currentBid'] as num?)?.toDouble() ?? 0.0;
    if (amount == null || amount <= currentBid) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('1st bid cannot exceed ₹${_formatCurrency(maxFirst)} (10x starting price ₹${_formatCurrency(startingPrice)}).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final channel = _roomChannels[roomId];
    if (channel != null) {
      channel.sink.add(jsonEncode({
        'type': 'place_bid',
        'amount': amount,
      }));
      controller.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WebSocket not connected for this category. Please wait.')),
      );
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }

    final bool isMultiCategory = _categories.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
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
            if (isMultiCategory)
              Text(
                'Group Auction • ${_categories.length} Categories',
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
                  Text('Spectator', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
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
          : Column(
              children: [
                // Spectator Banner
                if (_isSpectator)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1B5E20),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin Spectator Mode — Watching live group auction. Bidding disabled.',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top Category Switcher Tabs (Horizontal Bar)
                if (isMultiCategory) _buildCategorySwitcherBar(),

                // Main Content: All Categories Grid or Single Category Focus
                Expanded(
                  child: _selectedCategoryRoomId.isEmpty || _selectedCategoryRoomId == 'all'
                      ? _buildAllCategoriesMatrixView()
                      : _buildSingleCategoryDetailedView(_selectedCategoryRoomId),
                ),
              ],
            ),
    );
  }

  /// Horizontal category bar letting bidders toggle between "All Categories" and specific focused categories
  Widget _buildCategorySwitcherBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All Categories" Chip
            ChoiceChip(
              label: Text(
                'All Categories (${_categories.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: (_selectedCategoryRoomId.isEmpty || _selectedCategoryRoomId == 'all') ? Colors.white : Colors.black87,
                ),
              ),
              selected: (_selectedCategoryRoomId.isEmpty || _selectedCategoryRoomId == 'all'),
              selectedColor: const Color(0xFF0288D1),
              backgroundColor: Colors.grey[100],
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategoryRoomId = 'all');
                }
              },
            ),
            const SizedBox(width: 8),

            // Individual Category Chips with Live Badges
            ..._categories.map((cat) {
              final rId = cat['id']?.toString() ?? '';
              final state = _roomStates[rId] ?? {};
              final isSelected = _selectedCategoryRoomId == rId;
              final bool isLeading = state['isHighestBidder'] == true;
              final double curBid = (state['currentBid'] as num?)?.toDouble() ?? 0.0;
              final String catName = cat['category'] ?? cat['subcategory'] ?? cat['title'] ?? 'Lot';

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        catName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹${_formatCurrency(curBid)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF0288D1),
                        ),
                      ),
                      if (isLeading) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LEADING',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0288D1),
                  backgroundColor: isLeading ? const Color(0xFFE8F5E9) : Colors.grey[100],
                  onSelected: (selected) {
                    setState(() => _selectedCategoryRoomId = selected ? rId : 'all');
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// All Categories Grid / Matrix View: Every category displayed on the SAME page with full live bidding controls
  Widget _buildAllCategoriesMatrixView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final rId = cat['id']?.toString() ?? '';
            return _buildCategoryLiveBiddingCard(rId);
          },
        );
      },
    );
  }

  /// Self-contained live bidding card for each category in the group auction
  Widget _buildCategoryLiveBiddingCard(String roomId) {
    final state = _roomStates[roomId];
    if (state == null) return const SizedBox.shrink();

    final item = state['item'] as Map<String, dynamic>? ?? {};
    final String catName = (state['category'] ?? state['subcategory'] ?? 'Auction Category').toString().toUpperCase();
    final String itemName = item['name'] ?? state['title'] ?? 'Lot Item';
    final double currentBid = (state['currentBid'] as num?)?.toDouble() ?? 0.0;
    final double minBid = (state['minBid'] as num?)?.toDouble() ?? 0.0;
    final double minRaise = (state['minRaise'] as num?)?.toDouble() ?? 100.0;
    final int timeRem = (state['timeRemainingSec'] as int?) ?? 0;
    final bool isHighest = state['isHighestBidder'] == true;
    final bool isFirst = state['isFirstBid'] == true;
    final bool ended = state['auctionEnded'] == true;
    final controller = state['bidController'] as TextEditingController;
    final history = (state['bidHistory'] as List<Map<String, dynamic>>?) ?? [];
    final bool isExpanded = state['isExpanded'] == true;

    final List images = item['images'] is List ? item['images'] as List : [];
    final String? thumbUrl = images.isNotEmpty ? images[0].toString() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isHighest ? Border.all(color: const Color(0xFF4CAF50), width: 2) : null,
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Category pill, item name, and live countdown timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      catName,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Countdown Timer Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: timeRem < 120 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 13, color: timeRem < 120 ? Colors.red : Colors.green[800]),
                        const SizedBox(width: 4),
                        Text(
                          ended ? 'ENDED' : _formatTime(timeRem),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: timeRem < 120 ? Colors.red : Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body: Image, details, and current high bid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 76,
                      height: 76,
                      color: Colors.grey[100],
                      child: thumbUrl != null
                          ? Image.network(thumbUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 36, color: Colors.grey))
                          : const Icon(Icons.image, size: 36, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Bid Metrics
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT HIGH BID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${_formatCurrency(currentBid)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0288D1)),
                            ),
                            const SizedBox(width: 8),
                            if (isHighest)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(4)),
                                child: const Text('LEADING', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Start: ₹${_formatCurrency(minBid)}', style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 10),
                            Text('Min Raise: +₹${_formatCurrency(minRaise)}', style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Banner notifications inside card (Leading / 1st Bid Cap)
            if (isHighest)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You hold the highest bid on this category! Awaiting competitor bids.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (isFirst && minBid > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '1st Bid Cap: Max ₹${_formatCurrency(minBid * 10)} (10x start ₹${_formatCurrency(minBid)})',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF57F17), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Quick Increment Action Chips
            if (!ended && !_isSpectator && !isHighest)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildQuickRaiseChip(roomId, currentBid + minRaise, '+₹${_formatCurrency(minRaise)}'),
                    const SizedBox(width: 8),
                    _buildQuickRaiseChip(roomId, currentBid + (minRaise * 5), '+₹${_formatCurrency(minRaise * 5)}'),
                    const SizedBox(width: 8),
                    _buildQuickRaiseChip(roomId, currentBid + (minRaise * 10), '+₹${_formatCurrency(minRaise * 10)}'),
                  ],
                ),
              ),

            // Direct Bidding Input Row right on this category card
            if (!ended && !_isSpectator)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !isHighest,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: isHighest ? 'Leading this category' : 'Custom bid amount...',
                          prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isHighest ? null : () => _placeBidForRoom(roomId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0288D1),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: Text(
                        isHighest ? 'Leading' : 'Bid Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isHighest ? Colors.grey[600] : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Expandable Bid History preview toggle
            InkWell(
              onTap: () {
                setState(() {
                  state['isExpanded'] = !isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${history.length} Bids Placed  •  ${state['bidderCount']} Connected',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Text(
                          isExpanded ? 'Hide History' : 'View History',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0288D1), fontWeight: FontWeight.bold),
                        ),
                        Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: const Color(0xFF0288D1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Recent Bids Log
            if (isExpanded)
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF9FAFB),
                child: history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No bids yet for this category.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    : Column(
                        children: history.take(5).map((b) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(b['alias'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('₹${_formatCurrency(b['amount'] as num)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRaiseChip(String roomId, double targetAmount, String label) {
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
          side: const BorderSide(color: Color(0xFF90CAF9)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          backgroundColor: const Color(0xFFF0F9FF),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
      ),
    );
  }

  /// Single Category Focused View (Expanded view for a specific category while keeping switcher active)
  Widget _buildSingleCategoryDetailedView(String roomId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _buildCategoryLiveBiddingCard(roomId),
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
