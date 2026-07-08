import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

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
  WebSocketChannel? _channel;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;

  // Auction State
  double _currentBid = 0.0;
  int _bidderCount = 0;
  int _timeRemainingSec = 0;
  bool _auctionEnded = false;
  String? _winnerAlias;
  double? _winningBid;

  // Bid History list for UI
  final List<Map<String, dynamic>> _bidHistory = [];

  final TextEditingController _bidController = TextEditingController();
  final TextEditingController _tempEmailController = TextEditingController();
  final TextEditingController _tempPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Do not auto-connect, wait for user to authenticate using temp credentials
    _isLoading = false;
  }

  Future<void> _connectWebSocketWithToken(String token) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final baseWs = ApiService.baseUrl
          .replaceFirst(RegExp(r'^http'), 'ws')
          .replaceFirst('/api', '');

      final wsUrl = '$baseWs/ws/room/${widget.roomId}/';
      bool hasReceivedData = false;

      // 1. Attempt secure subprotocol connection
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['token', token],
      );

      _channel!.stream.listen(
        (message) {
          hasReceivedData = true;
          final data = jsonDecode(message);
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          if (!hasReceivedData && mounted) {
            // If the subprotocol handshake fails (e.g. on Chrome), fallback to query string
            _connectWebSocketLegacyFallback(baseWs, token);
          } else if (mounted) {
            setState(() {
              _errorMessage = "Connection error. Auction may be closed.";
            });
          }
        },
        onDone: () {
          if (!hasReceivedData && mounted) {
            // Handshake failed or connection closed without receiving data, fallback
            _connectWebSocketLegacyFallback(baseWs, token);
          } else if (mounted && !_auctionEnded) {
            setState(() {
              _errorMessage = "Auction closed by server.";
            });
          }
        },
      );

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to connect: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _connectWebSocketLegacyFallback(String baseWs, String token) {
    if (!mounted) return;

    _channel?.sink.close();

    setState(() {
      _isLoading = true;
    });

    final wsUrlLegacy = '$baseWs/ws/room/${widget.roomId}/?token=$token';

    _channel = WebSocketChannel.connect(Uri.parse(wsUrlLegacy));

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        _handleWebSocketMessage(data);
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = "Connection error. Auction may be closed.";
          });
        }
      },
      onDone: () {
        if (mounted && !_auctionEnded) {
          setState(() {
            _errorMessage = "Auction closed by server.";
          });
        }
      },
    );

    setState(() {
      _isLoading = false;
    });
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

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.ephemeralLogin(email, password);

    if (result['success']) {
      if (result['roomId'] != widget.roomId) {
        setState(() {
          _errorMessage = "The credentials supplied are for a different bidding room.";
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isAuthenticated = true;
      });
      _connectWebSocketWithToken(result['token']);
    } else {
      setState(() {
        _isLoading = false;
      });
      final errorMsg = result['error']?['error'] ?? 'Invalid or expired credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }


  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'];

    setState(() {
      if (type == 'room_state') {
        _currentBid = (data['current_bid'] as num).toDouble();
        _bidderCount = data['bidder_count'] as int;
        _timeRemainingSec = data['time_remaining_sec'] as int;
      } 
      else if (type == 'new_bid') {
        _currentBid = (data['amount'] as num).toDouble();
        _bidHistory.insert(0, {
          'alias': data['bidder_alias'],
          'amount': _currentBid,
          'time': DateTime.parse(data['timestamp']).toLocal(),
        });
      } 
      else if (type == 'countdown_tick') {
        _timeRemainingSec = data['seconds_remaining'] as int;
      } 
      else if (type == 'auction_ended') {
        _auctionEnded = true;
        _winnerAlias = data['winner_alias'];
        _winningBid = (data['winning_bid'] as num).toDouble();
        _showWinnerDialog();
      } 
      else if (type == 'error' || type == 'bid_rejected') {
        final reason = data['reason'] ?? data['message'] ?? 'Error placing bid';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), backgroundColor: Colors.red),
        );
        if (data['current_bid'] != null) {
          _currentBid = (data['current_bid'] as num).toDouble();
        }
      }
    });
  }

  void _placeBid() {
    if (_bidController.text.isEmpty) return;
    
    final amount = double.tryParse(_bidController.text);
    if (amount == null || amount <= _currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid must be higher than current bid (₹${_currentBid.toStringAsFixed(0)})')),
      );
      return;
    }

    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'place_bid',
        'amount': amount,
      }));
      _bidController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showWinnerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Auction Ended!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            Text('Winner: $_winnerAlias', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Winning Bid: ₹${_winningBid?.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Return to Listings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _bidController.dispose();
    _tempEmailController.dispose();
    _tempPasswordController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildLoginScreen();
    }
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.roomTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        )
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Status Header
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CURRENT BID', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${_currentBid.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _timeRemainingSec < 60 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _formatTime(_timeRemainingSec),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _timeRemainingSec < 60 ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    const Text('remaining', style: TextStyle(fontSize: 10)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.people, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('$_bidderCount Bidders Connected', style: const TextStyle(color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    ),

                    // Bid History
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bidHistory.length,
                        itemBuilder: (context, index) {
                          final bid = _bidHistory[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE1F5FE),
                                child: Icon(Icons.person, color: Color(0xFF0288D1)),
                              ),
                              title: Text(bid['alias'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${bid['time'].hour}:${bid['time'].minute.toString().padLeft(2, '0')}'),
                              trailing: Text(
                                '₹${bid['amount'].toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Bidding Controls
                    if (!_auctionEnded)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _bidController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Enter your bid...',
                                  prefixIcon: const Icon(Icons.currency_rupee),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _placeBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0288D1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              child: const Text('Place Bid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildLoginScreen() {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Enter Room: ${widget.roomTitle}'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_person_outlined,
                size: 80,
                color: Color(0xFF0288D1),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verification Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enter the one-time secure bidding credentials sent to your registered email for this specific room.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
              ] else ...[
                TextField(
                  controller: _tempEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'One-Time Bidding Email',
                    hintText: 'bidder_xxxx@auction.internal',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tempPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'One-Time Bidding Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _performEphemeralLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0288D1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Verify & Enter Room',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

