import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'enquiry_dialog.dart';
import '../services/api_service.dart';
import '../pages/live_auction_page.dart';
import '../utils/date_utils.dart';
import '../utils/number_to_words.dart';

// ─── Dashboard Homepage Section (shows 4 latest rooms) ────────────────────────

class AuctionSection extends StatefulWidget {
  const AuctionSection({super.key});

  @override
  State<AuctionSection> createState() => _AuctionSectionState();
}

class _AuctionSectionState extends State<AuctionSection> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final result = await ApiService.getRooms();
    if (mounted) {
      setState(() {
        _rooms = result['success'] == true
            ? ((result['data']['results'] as List<dynamic>?) ?? [])
            : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    final liveRooms = _rooms
        .where((r) => r is Map && r['status'] == 'live')
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
        
    final upcomingRooms = _rooms
        .where((r) => r is Map && r['status'] == 'upcoming')
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20.0,
        vertical: 60.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF0288D1)),
            ))
          else if (_rooms.isEmpty || (liveRooms.isEmpty && upcomingRooms.isEmpty))
            _buildEmptyState()
          else ...[
            _buildAuctionSection('LIVE NOW', 'Live Auctions', liveRooms, Colors.red, screenWidth, isMobile),
            if (liveRooms.isNotEmpty && upcomingRooms.isNotEmpty)
              const SizedBox(height: 60),
            _buildAuctionSection('EXCLUSIVE DEALS', 'Upcoming Auctions', upcomingRooms, const Color(0xFF0288D1), screenWidth, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildAuctionSection(
    String badgeText,
    String sectionTitle,
    List<Map<String, dynamic>> rooms,
    Color themeColor,
    double screenWidth,
    bool isMobile,
  ) {
    if (rooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (!isMobile && sectionTitle.contains('Upcoming'))
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/auction'),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('View All Auctions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0288D1),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 40),
        isMobile
            ? ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rooms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 24),
                itemBuilder: (context, index) => AuctionCard.fromRoom(rooms[index]),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: screenWidth > 1200 ? 2 : 1,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 30,
                  mainAxisSpacing: 30,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) => AuctionCard.fromRoom(rooms[index]),
              ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.gavel_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No auctions available right now',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Check back soon for upcoming auction listings.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}

// ─── AuctionCard ──────────────────────────────────────────────────────────────

class AuctionCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String type;        // 'Public Auction' | 'Private Auction' | 'Members Only'
  final DateTime? startTime;
  final DateTime? endTime;
  final String qty;
  final String unit;
  final String roomId;
  final String status;      // 'upcoming' | 'live' | 'ended' | 'draft'
  final String visibility;
  final bool isDelivered;
  final bool isApproved;
  final bool isTester;
  final bool isEmdRequired;
  final double emdAmount;

  const AuctionCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.type,
    this.startTime,
    this.endTime,
    required this.qty,
    this.unit = '',
    required this.roomId,
    required this.status,
    this.visibility = 'public',
    this.isDelivered = false,
    this.isApproved = false,
    this.isTester = false,
    this.isEmdRequired = false,
    this.emdAmount = 0.0,
  });

  /// Build an AuctionCard from the API response map
  factory AuctionCard.fromRoom(Map<String, dynamic> room) {
    final item = room['item'] as Map<String, dynamic>?;
    final images = item?['images'] as List<dynamic>?;
    final imageUrl = (images != null && images.isNotEmpty)
        ? images[0].toString()
        : 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=800&q=80';

    final visibility = room['visibility']?.toString() ?? 'public';
    final isDelivered = room['is_delivered'] == true;
    final isApproved = room['is_approved'] == true;
    final isTester = room['is_tester'] == true;

    String type;
    if (visibility == 'members_only') {
      type = (isApproved || isTester) ? 'Private (Member)' : '🔒 Private (Approval Required)';
    } else if (visibility == 'hidden') {
      type = 'Restricted';
    } else {
      type = 'Public Auction';
    }

    DateTime? startTime;
    DateTime? endTime;
    try {
      if (room['scheduled_start'] != null) {
        startTime = DateTimeUtils.parseUtc(room['scheduled_start'].toString());
      }
      if (room['scheduled_end'] != null) {
        endTime = DateTimeUtils.parseUtc(room['scheduled_end'].toString());
      }
    } catch (_) {}

    final rawQty = item?['quantity']?.toString() ?? '';
    final rawUnit = item?['unit']?.toString() ?? '';
    final regFee = room['registration_fee'] as Map<String, dynamic>?;
    final isEmdRequired = regFee?['required'] == true;
    final emdAmount = double.tryParse(regFee?['amount']?.toString() ?? '') ?? 0.0;

    final qtyDisplay = (visibility == 'members_only' && !isApproved && !isTester)
        ? '🔒 Approval Required'
        : rawQty;

    return AuctionCard(
      title: room['title']?.toString() ?? 'Untitled Auction',
      imageUrl: imageUrl,
      type: type,
      startTime: startTime,
      endTime: endTime,
      qty: qtyDisplay,
      unit: rawUnit,
      roomId: room['id']?.toString() ?? '',
      status: room['status']?.toString() ?? 'upcoming',
      visibility: visibility,
      isDelivered: isDelivered,
      isApproved: isApproved,
      isTester: isTester,
      isEmdRequired: isEmdRequired,
      emdAmount: emdAmount,
    );
  }

  @override
  State<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<AuctionCard> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;
  String _statusText = 'Loading...';
  Color _statusColor = const Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final start = widget.startTime;
    final end = widget.endTime;

    setState(() {
      if (widget.status == 'ended' || widget.status == 'cancelled') {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
      } else if (start != null && now.isBefore(start)) {
        _statusText = 'Starts In : ';
        _statusColor = const Color(0xFF555555);
        _timeLeft = start.difference(now);
      } else if (widget.status == 'live' || (start != null && end != null && now.isAfter(start) && now.isBefore(end))) {
        _statusText = 'LIVE NOW';
        _statusColor = Colors.red;
        _timeLeft = end != null ? end.difference(now) : Duration.zero;
      } else {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
      }
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'TBD';
    return DateTimeUtils.formatIST(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F9FE),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFCFE8F7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      widget.imageUrl,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 90,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _infoRow('Auction Type', widget.type, isBadge: true),
                        _infoRow('Start Time', _formatDateTime(widget.startTime)),
                        _infoRow('End Time', _formatDateTime(widget.endTime)),
                        if (widget.qty.isNotEmpty) _infoRow('Quantity', formatQuantityWithWords(widget.qty, widget.unit)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFCFE8F7))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isExtraSmall = constraints.maxWidth < 300;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: isExtraSmall ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: _statusColor,
                            ),
                          ),
                          if (_statusText != 'Auction Ended' && _statusText != 'Restricted') ...[
                            _timerBox('${_timeLeft.inDays}D', isExtraSmall),
                            _timerBox('${_timeLeft.inHours % 24}H', isExtraSmall),
                            _timeLeft.inMinutes > 0
                                ? _timerBox('${_timeLeft.inMinutes % 60}M', isExtraSmall)
                                : _timerBox('${_timeLeft.inSeconds % 60}S', isExtraSmall),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _actionButton(
                            context, 'View Details',
                            const Color(0xFF03A9F4),
                            () => AuctionDetailDialog.show(context, widget.roomId),
                            isExtraSmall,
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            context,
                            _statusText == 'LIVE NOW' ? 'Bid Now' : 'Show Interest',
                            _statusText == 'LIVE NOW' ? Colors.red : const Color(0xFF8BC34A),
                            () {
                              if (_statusText == 'LIVE NOW') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LiveAuctionPage(
                                      roomId: widget.roomId,
                                      roomTitle: widget.title,
                                    ),
                                  ),
                                );
                              } else {
                                EnquiryDialog.show(
                                  context,
                                  widget.title,
                                  auctionId: widget.roomId,
                                  isEmdRequired: widget.isEmdRequired,
                                  emdAmount: widget.emdAmount,
                                );
                              }
                            },
                            isExtraSmall,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF777777), fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else
            Flexible(
              child: Text(value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  Widget _timerBox(String text, bool isExtraSmall) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: EdgeInsets.symmetric(horizontal: isExtraSmall ? 4 : 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF03A9F4),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white, fontSize: isExtraSmall ? 9 : 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionButton(BuildContext context, String label, Color color, VoidCallback onPressed, bool isExtraSmall) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isExtraSmall ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                color: Colors.white, fontSize: isExtraSmall ? 10 : 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class AuctionDetailDialog {
  static void show(BuildContext context, String roomId) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService.getRoomDetails(roomId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF03A9F4)),
                ),
              );
            }
            if (snapshot.hasError || snapshot.data?['success'] != true) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Failed to load auction details.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                ],
              );
            }

            final room = snapshot.data!['data'];
            final item = room['item'] as Map<String, dynamic>?;
            final description = room['description']?.toString() ?? item?['description']?.toString() ?? 'No description available.';
            final start = room['scheduled_start'] != null ? DateTimeUtils.parseUtc(room['scheduled_start'].toString()) : null;
            final end = room['scheduled_end'] != null ? DateTimeUtils.parseUtc(room['scheduled_end'].toString()) : null;
            final visibility = room['visibility']?.toString() ?? 'public';
            final isApproved = room['is_approved'] == true;
            final isTester = room['is_tester'] == true;
            final isDelivered = room['is_delivered'] == true;
            final isLocked = (visibility == 'members_only' && !isApproved && !isTester);

            final minBid = item?['min_bid'] ?? 0;
            final minRaise = item?['min_raise'] ?? 0;
            final minBidStr = isLocked ? '🔒 Available upon Approval' : formatCurrency(minBid);
            final minRaiseStr = isLocked ? '🔒 Available upon Approval' : formatCurrency(minRaise);
            final rawUnit = item?['unit']?.toString() ?? '';
            final regFee = room['registration_fee'] as Map<String, dynamic>?;
            final isEmdRequired = regFee?['required'] == true;
            final emdAmount = double.tryParse(regFee?['amount']?.toString() ?? '') ?? 0.0;
            final emdStr = isEmdRequired ? '${formatCurrency(emdAmount)} (Mandatory)' : 'Not Required (Free)';
            final qtyStr = isLocked ? '🔒 Available upon Approval' : formatQuantityWithWords(item?['quantity'], rawUnit);
            final deliveryStr = isDelivered ? '✅ Item Delivered' : (room['status'] == 'ended' ? '🚚 Delivery Pending' : 'Not Applicable');

            final df = DateFormat('dd MMM yyyy hh:mm a');

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            room['title'] ?? 'Auction Details',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    _detailRow('Status', room['status']?.toString().toUpperCase() ?? 'UPCOMING'),
                    _detailRow('Visibility', visibility == 'members_only' ? '🔒 Private (Members Only)' : 'Public'),
                    _detailRow('Quantity', qtyStr),
                    _detailRow('EMD / Registration Fee', emdStr),
                    _detailRow('Scheduled Start', start != null ? DateTimeUtils.formatIST(start) : 'TBD'),
                    _detailRow('Scheduled End', end != null ? DateTimeUtils.formatIST(end) : 'TBD'),
                    _detailRow('Minimum Bid / Base Price', minBidStr),
                    _detailRow('Minimum Raise Increment', minRaiseStr),
                    _detailRow('Location', item?['location'] ?? 'Not Specified'),
                    if (room['status'] == 'ended') _detailRow('Delivery Status', deliveryStr),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03A9F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
