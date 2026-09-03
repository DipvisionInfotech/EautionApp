import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'enquiry_dialog.dart';
import '../services/api_service.dart';
import '../pages/live_auction_page.dart';
import '../utils/date_utils.dart';
import '../utils/number_to_words.dart';

// ─── AuctionDisplayItem (Groups rooms by group_id) ───────────────────────────

class AuctionDisplayItem {
  final bool isGroup;
  final String groupId;
  final String title;
  final List<String> allImages;
  final String type;
  final DateTime? startTime;
  final DateTime? endTime;
  final String qty;
  final String unit;
  final String roomId;
  final String status;
  final String visibility;
  final bool isDelivered;
  final bool isApproved;
  final bool isTester;
  final bool isEmdRequired;
  final double emdAmount;
  final List<Map<String, dynamic>> lots;
  final Map<String, dynamic>? singleRoom;

  AuctionDisplayItem({
    required this.isGroup,
    required this.groupId,
    required this.title,
    required this.allImages,
    required this.type,
    this.startTime,
    this.endTime,
    this.qty = '',
    this.unit = '',
    this.roomId = '',
    required this.status,
    this.visibility = 'public',
    this.isDelivered = false,
    this.isApproved = false,
    this.isTester = false,
    this.isEmdRequired = false,
    this.emdAmount = 0.0,
    required this.lots,
    this.singleRoom,
  });

  /// Group a list of raw room maps from /api/rooms/ into unified display items
  static List<AuctionDisplayItem> groupRooms(List<Map<String, dynamic>> rawRooms) {
    final Map<String, List<Map<String, dynamic>>> groupMap = {};
    final List<AuctionDisplayItem> displayItems = [];

    for (final room in rawRooms) {
      final isGroup = room['is_group_auction'] == true ||
          (room['group_id'] != null && room['group_id'].toString().trim().isNotEmpty);
      final groupId = room['group_id']?.toString().trim() ?? '';

      if (isGroup && groupId.isNotEmpty) {
        groupMap.putIfAbsent(groupId, () => []).add(room);
      } else {
        displayItems.add(_fromSingleRoom(room));
      }
    }

    // Process all group auctions
    groupMap.forEach((groupId, lots) {
      displayItems.add(_fromGroupLots(groupId, lots));
    });

    return displayItems;
  }

  static AuctionDisplayItem _fromSingleRoom(Map<String, dynamic> room) {
    final item = room['item'] as Map<String, dynamic>?;
    final rawImgs = item?['images'] as List<dynamic>?;
    final List<String> images = (rawImgs != null && rawImgs.isNotEmpty)
        ? rawImgs.map((e) => e.toString()).toList()
        : [];

    final visibility = room['visibility']?.toString() ?? 'public';
    final isApproved = room['is_approved'] == true;
    final isTester = room['is_tester'] == true;
    final isDelivered = room['is_delivered'] == true;

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

    String status = room['status']?.toString() ?? 'upcoming';
    if (status == 'live' || status == 'upcoming') {
      if (endTime != null && (DateTime.now().isAfter(endTime) || DateTime.now().isAtSameMomentAs(endTime))) {
        status = 'ended';
      }
    }

    final rawQty = item?['quantity']?.toString() ?? '';
    final rawUnit = item?['unit']?.toString() ?? '';
    final regFee = room['registration_fee'] as Map<String, dynamic>?;
    final isEmdRequired = regFee?['required'] == true;
    final emdAmount = double.tryParse(regFee?['amount']?.toString() ?? '') ?? 0.0;

    final qtyDisplay = (visibility == 'members_only' && !isApproved && !isTester)
        ? '🔒 Approval Required'
        : rawQty;

    return AuctionDisplayItem(
      isGroup: false,
      groupId: '',
      title: room['title']?.toString() ?? 'Untitled Auction',
      allImages: images,
      type: type,
      startTime: startTime,
      endTime: endTime,
      qty: qtyDisplay,
      unit: rawUnit,
      roomId: room['id']?.toString() ?? '',
      status: status,
      visibility: visibility,
      isDelivered: isDelivered,
      isApproved: isApproved,
      isTester: isTester,
      isEmdRequired: isEmdRequired,
      emdAmount: emdAmount,
      lots: [room],
      singleRoom: room,
    );
  }

  static AuctionDisplayItem _fromGroupLots(String groupId, List<Map<String, dynamic>> lots) {
    final first = lots.first;
    final groupTitle = (first['group_title']?.toString().isNotEmpty == true)
        ? first['group_title'].toString()
        : (first['title']?.toString() ?? 'Group Auction');

    // Flatten all images across all lots
    final List<String> allImages = [];
    for (final lot in lots) {
      final item = lot['item'] as Map<String, dynamic>?;
      final imgs = item?['images'] as List<dynamic>?;
      if (imgs != null) {
        for (final img in imgs) {
          final s = img.toString();
          if (s.isNotEmpty && !allImages.contains(s)) {
            allImages.add(s);
          }
        }
      }
    }

    // Determine timing range
    DateTime? minStart;
    DateTime? maxEnd;
    for (final lot in lots) {
      try {
        if (lot['scheduled_start'] != null) {
          final s = DateTimeUtils.parseUtc(lot['scheduled_start'].toString());
          if (minStart == null || s.isBefore(minStart)) minStart = s;
        }
        if (lot['scheduled_end'] != null) {
          final e = DateTimeUtils.parseUtc(lot['scheduled_end'].toString());
          if (maxEnd == null || e.isAfter(maxEnd)) maxEnd = e;
        }
      } catch (_) {}
    }

    // Determine status
    String status = 'upcoming';
    if (lots.every((l) => l['status'] == 'ended')) {
      status = 'ended';
    } else if (maxEnd != null && (DateTime.now().isAfter(maxEnd) || DateTime.now().isAtSameMomentAs(maxEnd))) {
      status = 'ended';
    } else if (lots.any((l) => l['status'] == 'live')) {
      status = 'live';
    } else if (lots.any((l) => l['status'] == 'upcoming')) {
      status = 'upcoming';
    }

    final visibility = first['visibility']?.toString() ?? 'public';
    final isApproved = lots.every((l) => l['is_approved'] == true);
    final isTester = lots.any((l) => l['is_tester'] == true);
    final isDelivered = lots.every((l) => l['is_delivered'] == true);

    String type;
    if (visibility == 'members_only') {
      type = (isApproved || isTester) ? 'Private (Member)' : '🔒 Private (Approval Required)';
    } else if (visibility == 'hidden') {
      type = 'Restricted';
    } else {
      type = 'Public Auction';
    }

    bool isEmdRequired = false;
    double emdAmount = 0.0;
    for (final l in lots) {
      final rf = l['registration_fee'] as Map<String, dynamic>?;
      if (rf?['required'] == true) {
        isEmdRequired = true;
        final amt = double.tryParse(rf?['amount']?.toString() ?? '') ?? 0.0;
        if (amt > emdAmount) {
          emdAmount = amt;
        }
      }
    }

    return AuctionDisplayItem(
      isGroup: true,
      groupId: groupId,
      title: groupTitle,
      allImages: allImages,
      type: type,
      startTime: minStart,
      endTime: maxEnd,
      status: status,
      visibility: visibility,
      isDelivered: isDelivered,
      isApproved: isApproved,
      isTester: isTester,
      isEmdRequired: isEmdRequired,
      emdAmount: emdAmount,
      lots: lots,
      singleRoom: null,
    );
  }
}

// ─── ImageSlideshowBox ────────────────────────────────────────────────────────

class ImageSlideshowBox extends StatefulWidget {
  final List<String> images;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ImageSlideshowBox({
    super.key,
    required this.images,
    this.width = 120,
    this.height = 90,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<ImageSlideshowBox> createState() => _ImageSlideshowBoxState();
}

class _ImageSlideshowBoxState extends State<ImageSlideshowBox> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSlideshow();
  }

  @override
  void didUpdateWidget(covariant ImageSlideshowBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _currentIndex = 0;
      _startSlideshow();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSlideshow() {
    _timer?.cancel();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (mounted && widget.images.isNotEmpty) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFFE2E8F0),
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 28),
          ),
        ),
      );
    }

    final currentUrl = widget.images[_currentIndex % widget.images.length];

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFE2E8F0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Image.network(
                currentUrl,
                key: ValueKey(currentUrl),
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library, color: Colors.white, size: 9),
                      const SizedBox(width: 3),
                      Text(
                        '${_currentIndex + 1}/${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Homepage Section ───────────────────────────────────────────────

class AuctionSection extends StatefulWidget {
  const AuctionSection({super.key});

  @override
  State<AuctionSection> createState() => _AuctionSectionState();
}

class _AuctionSectionState extends State<AuctionSection> {
  List<AuctionDisplayItem> _allItems = [];
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
        if (result['success'] == true) {
          final rawList = ((result['data']['results'] as List<dynamic>?) ?? [])
              .where((r) => r is Map)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          _allItems = AuctionDisplayItem.groupRooms(rawList);
        } else {
          _allItems = [];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    final now = DateTime.now();
    final liveItems = _allItems.where((i) {
      if (i.status == 'ended' || i.status == 'cancelled') return false;
      if (i.endTime != null && (now.isAfter(i.endTime!) || now.isAtSameMomentAs(i.endTime!))) return false;
      return i.status == 'live';
    }).toList();

    final upcomingItems = _allItems.where((i) {
      if (i.status == 'ended' || i.status == 'cancelled') return false;
      if (i.endTime != null && (now.isAfter(i.endTime!) || now.isAtSameMomentAs(i.endTime!))) return false;
      return i.status == 'upcoming';
    }).toList();

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
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF0288D1)),
              ),
            )
          else if (_allItems.isEmpty || (liveItems.isEmpty && upcomingItems.isEmpty))
            _buildEmptyState()
          else ...[
            _buildAuctionSection('LIVE NOW', 'Live Auctions', liveItems, Colors.red, screenWidth, isMobile),
            if (liveItems.isNotEmpty && upcomingItems.isNotEmpty) const SizedBox(height: 60),
            _buildAuctionSection('EXCLUSIVE DEALS', 'Upcoming Auctions', upcomingItems, const Color(0xFF0288D1), screenWidth, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildAuctionSection(
    String badgeText,
    String sectionTitle,
    List<AuctionDisplayItem> items,
    Color themeColor,
    double screenWidth,
    bool isMobile,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
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
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) => _renderCard(items[index]),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: screenWidth > 1200 ? 2 : 1,
                  mainAxisExtent: 250,
                  crossAxisSpacing: 30,
                  mainAxisSpacing: 30,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _renderCard(items[index]),
              ),
      ],
    );
  }

  Widget _renderCard(AuctionDisplayItem item) {
    if (item.isGroup) {
      return GroupAuctionCard(item: item);
    }
    return AuctionCard.fromDisplayItem(item);
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

// ─── AuctionCard (Single Lot) ─────────────────────────────────────────────────

class AuctionCard extends StatefulWidget {
  final String title;
  final List<String> images;
  final String type;
  final DateTime? startTime;
  final DateTime? endTime;
  final String qty;
  final String unit;
  final String roomId;
  final String status;
  final String visibility;
  final bool isDelivered;
  final bool isApproved;
  final bool isTester;
  final bool isEmdRequired;
  final double emdAmount;

  const AuctionCard({
    super.key,
    required this.title,
    required this.images,
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

  factory AuctionCard.fromDisplayItem(AuctionDisplayItem item) {
    return AuctionCard(
      title: item.title,
      images: item.allImages,
      type: item.type,
      startTime: item.startTime,
      endTime: item.endTime,
      qty: item.qty,
      unit: item.unit,
      roomId: item.roomId,
      status: item.status,
      visibility: item.visibility,
      isDelivered: item.isDelivered,
      isApproved: item.isApproved,
      isTester: item.isTester,
      isEmdRequired: item.isEmdRequired,
      emdAmount: item.emdAmount,
    );
  }

  factory AuctionCard.fromRoom(Map<String, dynamic> room) {
    final displayItem = AuctionDisplayItem._fromSingleRoom(room);
    return AuctionCard.fromDisplayItem(displayItem);
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
      } else if (end != null && (now.isAfter(end) || now.isAtSameMomentAs(end))) {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
      } else if (start != null && now.isBefore(start)) {
        _statusText = 'Starts In : ';
        _statusColor = const Color(0xFF555555);
        final diff = start.difference(now);
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      } else if (widget.status == 'live' ||
          (start != null && end != null && now.isAfter(start) && now.isBefore(end))) {
        if (end != null) {
          final diff = end.difference(now);
          if (diff.isNegative || diff == Duration.zero) {
            _statusText = 'Auction Ended';
            _statusColor = Colors.grey;
            _timeLeft = Duration.zero;
          } else {
            _statusText = 'LIVE NOW';
            _statusColor = Colors.red;
            _timeLeft = diff;
          }
        } else {
          _statusText = 'LIVE NOW';
          _statusColor = Colors.red;
          _timeLeft = Duration.zero;
        }
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
                  ImageSlideshowBox(
                    images: widget.images,
                    width: 120,
                    height: 90,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _infoRow('Auction Type', widget.type, isBadge: true),
                        _infoRow('Start Time', _formatDateTime(widget.startTime)),
                        _infoRow('End Time', _formatDateTime(widget.endTime)),
                        if (widget.isEmdRequired && widget.emdAmount > 0)
                          _infoRow('Joining Fee', formatCurrency(widget.emdAmount), isBadge: true, badgeColor: const Color(0xFF059669)),
                        if (widget.qty.isNotEmpty)
                          _infoRow('Quantity', formatQuantityWithWords(widget.qty, widget.unit)),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFCFE8F7))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isExtraSmall = constraints.maxWidth < 320;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _statusText,
                              style: TextStyle(
                                fontSize: isExtraSmall ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color: _statusColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_statusText != 'Auction Ended' &&
                              _statusText != 'Restricted' &&
                              !_timeLeft.isNegative &&
                              _timeLeft > Duration.zero) ...[
                            if (_timeLeft.inDays > 0)
                              _timerBox('${_timeLeft.inDays}D', isExtraSmall),
                            if (_timeLeft.inHours > 0 || _timeLeft.inDays > 0)
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
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _actionButton(
                                  context,
                                  'View Details',
                                  const Color(0xFF03A9F4),
                                  () => AuctionDetailDialog.show(context, widget.roomId),
                                  isExtraSmall,
                                ),
                                if (_statusText != 'Auction Ended')
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

  Widget _infoRow(String label, String value, {bool isBadge = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF777777), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          if (isBadge)
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFF0288D1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
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

// ─── GroupAuctionCard (Multi-Lot Group Auction Card) ──────────────────────────

class GroupAuctionCard extends StatefulWidget {
  final AuctionDisplayItem item;

  const GroupAuctionCard({super.key, required this.item});

  @override
  State<GroupAuctionCard> createState() => _GroupAuctionCardState();
}

class _GroupAuctionCardState extends State<GroupAuctionCard> {
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
    final start = widget.item.startTime;
    final end = widget.item.endTime;

    setState(() {
      if (widget.item.status == 'ended' || widget.item.status == 'cancelled') {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
      } else if (end != null && (now.isAfter(end) || now.isAtSameMomentAs(end))) {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
      } else if (start != null && now.isBefore(start)) {
        _statusText = 'Starts In : ';
        _statusColor = const Color(0xFF555555);
        final diff = start.difference(now);
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      } else if (widget.item.status == 'live' ||
          (start != null && end != null && now.isAfter(start) && now.isBefore(end))) {
        if (end != null) {
          final diff = end.difference(now);
          if (diff.isNegative || diff == Duration.zero) {
            _statusText = 'Auction Ended';
            _statusColor = Colors.grey;
            _timeLeft = Duration.zero;
          } else {
            _statusText = 'LIVE NOW';
            _statusColor = Colors.red;
            _timeLeft = diff;
          }
        } else {
          _statusText = 'LIVE NOW';
          _statusColor = Colors.red;
          _timeLeft = Duration.zero;
        }
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

  String _getLotsSummary() {
    if (widget.item.lots.isEmpty) return 'No lots';
    final lotNames = widget.item.lots.map((l) {
      final item = l['item'] as Map<String, dynamic>?;
      return item?['name']?.toString() ?? l['title']?.toString() ?? 'Lot';
    }).toList();
    return lotNames.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Subtle emerald/teal tint for group auctions
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                  ImageSlideshowBox(
                    images: widget.item.allImages,
                    width: 120,
                    height: 90,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.layers_rounded, color: Colors.white, size: 11),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        '${widget.item.lots.length} LOTS GROUP',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0288D1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.item.type,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        _infoRow('Start Time', _formatDateTime(widget.item.startTime)),
                        _infoRow('End Time', _formatDateTime(widget.item.endTime)),
                        if (widget.item.isEmdRequired && widget.item.emdAmount > 0)
                          _infoRow('Joining Fee', formatCurrency(widget.item.emdAmount), isBadge: true, badgeColor: const Color(0xFF059669)),
                        _infoRow('Includes', _getLotsSummary()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFBBF7D0))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isExtraSmall = constraints.maxWidth < 320;
                  final now = DateTime.now();
                  int totalLots = widget.item.lots.length;
                  int liveLots = 0;
                  int endedLots = 0;
                  final nowUtc = now.toUtc();
                  for (final lot in widget.item.lots) {
                    final s = (lot['status']?.toString() ?? 'upcoming').toLowerCase().trim();
                    DateTime? lotEnd;
                    final dynamic rawEnd = lot['scheduled_end'] ??
                        lot['scheduledEnd'] ??
                        lot['end_time'] ??
                        lot['endTime'] ??
                        widget.item.endTime;
                    if (rawEnd != null) {
                      final e = rawEnd is DateTime ? rawEnd.toUtc() : DateTimeUtils.parseUtc(rawEnd.toString());
                      if (e.millisecondsSinceEpoch > 0) {
                        lotEnd = e;
                      }
                    }
                    final bool isExpired = lotEnd != null && (nowUtc.isAfter(lotEnd) || nowUtc.isAtSameMomentAs(lotEnd));
                    final bool isEnded = isExpired || s == 'ended' || s == 'completed' || s == 'expired' || s == 'cancelled' || s == 'closed';
                    if (isEnded) {
                      endedLots++;
                    } else if (s == 'live') {
                      liveLots++;
                    }
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: isExtraSmall ? 10 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (liveLots > 0 || endedLots > 0) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '(${liveLots > 0 ? '$liveLots/$totalLots Live' : ''}${liveLots > 0 && endedLots > 0 ? ' • ' : ''}${endedLots > 0 ? '$endedLots/$totalLots Ended' : ''})',
                                      style: TextStyle(
                                        fontSize: isExtraSmall ? 9 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_statusText != 'Auction Ended' &&
                              _statusText != 'Restricted' &&
                              !_timeLeft.isNegative &&
                              _timeLeft > Duration.zero) ...[
                            if (_timeLeft.inDays > 0)
                              _timerBox('${_timeLeft.inDays}D', isExtraSmall),
                            if (_timeLeft.inHours > 0 || _timeLeft.inDays > 0)
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
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _actionButton(
                                  context,
                                  'View All Lots (${widget.item.lots.length})',
                                  const Color(0xFF0288D1),
                                  () => GroupAuctionDetailDialog.show(
                                    context,
                                    widget.item.groupId,
                                    widget.item.lots,
                                    widget.item.title,
                                    widget.item.allImages,
                                    widget.item.isEmdRequired,
                                    widget.item.emdAmount,
                                  ),
                                  isExtraSmall,
                                ),
                                if (_statusText != 'Auction Ended')
                                  _actionButton(
                                    context,
                                    _statusText == 'LIVE NOW' ? 'Bid Now' : 'Show Interest',
                                    _statusText == 'LIVE NOW' ? Colors.red : const Color(0xFF059669),
                                    () {
                                      // Always open the detail dialog — per-lot bidding/interest handled inside
                                      GroupAuctionDetailDialog.show(
                                        context,
                                        widget.item.groupId,
                                        widget.item.lots,
                                        widget.item.title,
                                        widget.item.allImages,
                                        widget.item.isEmdRequired,
                                        widget.item.emdAmount,
                                      );
                                    },
                                    isExtraSmall,
                                  ),
                              ],
                            ),
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

  Widget _infoRow(String label, String value, {bool isBadge = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          if (isBadge)
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
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
        color: const Color(0xFF059669),
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

// ─── GroupAuctionDetailDialog ─────────────────────────────────────────────────

class GroupAuctionDetailDialog extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> lots;
  final String groupTitle;
  final List<String> allImages;
  final bool isEmdRequired;
  final double emdAmount;

  const GroupAuctionDetailDialog({
    super.key,
    required this.groupId,
    required this.lots,
    required this.groupTitle,
    required this.allImages,
    this.isEmdRequired = false,
    this.emdAmount = 0.0,
  });

  static void show(
    BuildContext context,
    String groupId,
    List<Map<String, dynamic>> lots,
    String groupTitle,
    List<String> allImages, [
    bool isEmdRequired = false,
    double emdAmount = 0.0,
  ]) {
    showDialog(
      context: context,
      builder: (context) => GroupAuctionDetailDialog(
        groupId: groupId,
        lots: lots,
        groupTitle: groupTitle,
        allImages: allImages,
        isEmdRequired: isEmdRequired,
        emdAmount: emdAmount,
      ),
    );
  }

  @override
  State<GroupAuctionDetailDialog> createState() => _GroupAuctionDetailDialogState();
}

class _GroupAuctionDetailDialogState extends State<GroupAuctionDetailDialog> {
  Timer? _liveTicker;

  @override
  void initState() {
    super.initState();
    // Live ticker timer to update all lot timers across cards every second
    _liveTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1250 ? 1160.0 : (screenWidth > 900 ? 920.0 : (screenWidth * 0.96));

    final sortedLots = List<Map<String, dynamic>>.from(widget.lots);
    sortedLots.sort((a, b) {
      final aCreated = a['created_at']?.toString() ?? '';
      final bCreated = b['created_at']?.toString() ?? '';
      if (aCreated.isNotEmpty && bCreated.isNotEmpty) {
        return aCreated.compareTo(bCreated);
      }
      final aId = a['id']?.toString() ?? '';
      final bId = b['id']?.toString() ?? '';
      return aId.compareTo(bId);
    });

    final firstLot = sortedLots.isNotEmpty ? sortedLots.first : null;
    final start = firstLot?['scheduled_start'] != null
        ? DateTimeUtils.parseUtc(firstLot!['scheduled_start'].toString())
        : null;
    final end = firstLot?['scheduled_end'] != null
        ? DateTimeUtils.parseUtc(firstLot!['scheduled_end'].toString())
        : null;

    final regFee = firstLot?['registration_fee'] as Map<String, dynamic>?;
    final isEmdRequired = widget.isEmdRequired || regFee?['required'] == true;
    final emdAmount = widget.emdAmount > 0
        ? widget.emdAmount
        : (double.tryParse(regFee?['amount']?.toString() ?? '') ?? 0.0);

    final now = DateTime.now();
    final nowUtc = now.toUtc();
    int liveCount = 0;
    int endedCount = 0;
    for (final lot in sortedLots) {
      final s = (lot['status']?.toString() ?? 'upcoming').toLowerCase().trim();
      DateTime? lotEnd;
      final dynamic rawEnd = lot['scheduled_end'] ??
          lot['scheduledEnd'] ??
          lot['end_time'] ??
          lot['endTime'] ??
          end;
      if (rawEnd != null) {
        final e = rawEnd is DateTime ? rawEnd.toUtc() : DateTimeUtils.parseUtc(rawEnd.toString());
        if (e.millisecondsSinceEpoch > 0) {
          lotEnd = e;
        }
      }
      final bool isExpired = lotEnd != null && (nowUtc.isAfter(lotEnd) || nowUtc.isAtSameMomentAs(lotEnd));
      final bool isEnded = isExpired || s == 'ended' || s == 'completed' || s == 'expired' || s == 'cancelled' || s == 'closed';
      if (isEnded) {
        endedCount++;
      } else if (s == 'live') {
        liveCount++;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Color(0xFF6EE7B7), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Group ID: ${widget.groupId} • ${sortedLots.length} Lots',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                              ),
                            ),
                            if (liveCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$liveCount LIVE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body with Card Grid ──────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact Event Summary Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _summaryPill(
                            Icons.calendar_month_outlined,
                            'Schedule',
                            '${start != null ? DateTimeUtils.formatIST(start) : "TBD"} – ${end != null ? DateTimeUtils.formatIST(end) : "TBD"}',
                          ),
                          _summaryPill(
                            Icons.inventory_2_outlined,
                            'Total Lots',
                            '${sortedLots.length} Items / Lots',
                          ),
                          _summaryPill(
                            Icons.verified_user_outlined,
                            'EMD / Reg. Fee',
                            isEmdRequired ? '${formatCurrency(emdAmount)} (Required)' : 'Free / Not Required',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Auction Lots (${sortedLots.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        const Text(
                          'Select lot to bid or enquire',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Responsive Lot Cards Grid (Max 3 per row) ─────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        // 3 columns on wide screens, 2 columns on medium, 1 on narrow
                        final int columns = width >= 780 ? 3 : (width >= 480 ? 2 : 1);
                        const double spacing = 14.0;
                        final double cardWidth = (width - (spacing * (columns - 1))) / columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: List.generate(sortedLots.length, (idx) {
                            final lot = sortedLots[idx];
                            return SizedBox(
                              width: cardWidth,
                              child: _buildLotCard(
                                context: context,
                                lot: lot,
                                idx: idx,
                                now: now,
                                isEmdRequired: isEmdRequired,
                                emdAmount: emdAmount,
                                groupStart: start,
                                groupEnd: end,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Dialog Footer ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      EnquiryDialog.show(
                        context,
                        widget.groupTitle,
                        auctionId: widget.lots.isNotEmpty ? widget.lots.first['id']?.toString() : null,
                        isEmdRequired: isEmdRequired,
                        emdAmount: emdAmount,
                      );
                    },
                    icon: const Icon(Icons.all_inclusive, size: 16),
                    label: const Text('Register Interest for All Lots'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lot Card Widget ──────────────────────────────────────────────────────────
  Widget _buildLotCard({
    required BuildContext context,
    required Map<String, dynamic> lot,
    required int idx,
    required DateTime now,
    required bool isEmdRequired,
    required double emdAmount,
    DateTime? groupStart,
    DateTime? groupEnd,
  }) {
    final item = lot['item'] as Map<String, dynamic>?;
    final lotTitle = lot['title']?.toString() ?? 'Lot ${idx + 1}';
    final itemName = item?['name']?.toString() ?? '';
    final category = lot['category']?.toString() ?? 'General';
    final qty = item?['quantity']?.toString() ?? '1';
    final unit = item?['unit']?.toString() ?? 'Units';
    final minBid = item?['min_bid'] ?? 0;
    final minRaise = item?['min_raise'] ?? 0;
    final lotImgs = (item?['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final lotRoomId = lot['id']?.toString() ?? '';
    final location = item?['location']?.toString() ?? '';

    // Timings & Status
    DateTime? lotStart;
    DateTime? lotEnd;

    final dynamic rawStart = lot['scheduled_start'] ??
        lot['scheduledStart'] ??
        lot['start_time'] ??
        lot['startTime'] ??
        lot['scheduled_start_time'] ??
        groupStart;

    final dynamic rawEnd = lot['scheduled_end'] ??
        lot['scheduledEnd'] ??
        lot['end_time'] ??
        lot['endTime'] ??
        lot['scheduled_end_time'] ??
        groupEnd;

    if (rawStart != null) {
      if (rawStart is DateTime) {
        lotStart = rawStart.toUtc();
      } else {
        final s = DateTimeUtils.parseUtc(rawStart.toString());
        if (s.millisecondsSinceEpoch > 0) {
          lotStart = s;
        }
      }
    }
    if (rawEnd != null) {
      if (rawEnd is DateTime) {
        lotEnd = rawEnd.toUtc();
      } else {
        final e = DateTimeUtils.parseUtc(rawEnd.toString());
        if (e.millisecondsSinceEpoch > 0) {
          lotEnd = e;
        }
      }
    }

    final rawStatus = (lot['status']?.toString() ?? 'upcoming').toLowerCase().trim();
    final nowUtc = now.toUtc();
    final bool isExpired = lotEnd != null && (nowUtc.isAfter(lotEnd.toUtc()) || nowUtc.isAtSameMomentAs(lotEnd.toUtc()));
    final bool isStatusEnded = rawStatus == 'ended' ||
        rawStatus == 'completed' ||
        rawStatus == 'expired' ||
        rawStatus == 'cancelled' ||
        rawStatus == 'closed' ||
        lot['is_ended'] == true ||
        lot['isEnded'] == true;

    final bool lotIsEnded = isExpired || isStatusEnded;
    final String lotStatus = lotIsEnded ? 'ended' : rawStatus;

    final lotVisibility = lot['visibility']?.toString() ?? 'public';
    final lotIsApproved = lot['is_approved'] == true;
    final lotIsTester = lot['is_tester'] == true;
    final lotIsPrivate = lotVisibility == 'members_only';
    final lotIsAccessible = !lotIsPrivate || lotIsApproved || lotIsTester;

    final bool lotIsLive = !lotIsEnded && (
        lotStatus == 'live' ||
        (lotStart != null && nowUtc.isAfter(lotStart.toUtc()) && (lotEnd == null || nowUtc.isBefore(lotEnd.toUtc())))
    );

    final canBid = !lotIsEnded && lotIsLive && lotIsAccessible;
    final isLocked = !lotIsEnded && lotIsPrivate && !lotIsApproved && !lotIsTester;

    // Timer string & display text
    final timerString = _formatLotCountdown(lotStart, lotEnd, lotStatus, now);

    final lotRegFee = lot['registration_fee'] as Map<String, dynamic>?;
    final bool lotFeeRequired = lotRegFee?['required'] == true || isEmdRequired;
    final double lotFeeAmount = (lotRegFee?['required'] == true && double.tryParse(lotRegFee?['amount']?.toString() ?? '') != null)
        ? (double.tryParse(lotRegFee!['amount'].toString()) ?? 0.0)
        : emdAmount;

    // Image url for this specific lot
    final displayImg = lotImgs.isNotEmpty
        ? lotImgs.first
        : (widget.allImages.isNotEmpty ? widget.allImages.first : '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lotIsLive
              ? const Color(0xFFEF4444).withOpacity(0.4)
              : (isLocked ? const Color(0xFFFFCDD2) : const Color(0xFFE2E8F0)),
          width: lotIsLive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: lotIsLive ? const Color(0xFFEF4444).withOpacity(0.06) : Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Specific Lot Image Header with Badges & Timer ───────────
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: displayImg.isNotEmpty
                    ? Image.network(
                        displayImg,
                        width: double.infinity,
                        height: 145,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),

              // Gradient overlay for text legibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Top-Left: Lot Number & Category
              Positioned(
                top: 8,
                left: 8,
                child: Wrap(
                  spacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LOT ${idx + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0288D1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Top-Right: Per-Lot Live Countdown Timer / Status Badge
              Positioned(
                top: 8,
                right: 8,
                child: _buildTimerBadge(lotIsLive, lotIsEnded, isLocked, timerString),
              ),

              // Bottom-Right: Image counter if multiple
              if (lotImgs.length > 1)
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          '${lotImgs.length} photos',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Lot Card Body ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  lotTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (itemName.isNotEmpty && itemName != lotTitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    itemName,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Location
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),

                // Joining Fee Badge (if configured and lot is not ended)
                if (lotFeeRequired && lotFeeAmount > 0 && !lotIsEnded) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payments_outlined, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 5),
                            Text(
                              'Joining / Reg. Fee',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                            ),
                          ],
                        ),
                        Text(
                          formatCurrency(lotFeeAmount),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Pricing & Quantity Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _cardStat('Quantity', isLocked ? '🔒 Hidden' : formatQuantityWithWords(qty, unit)),
                      Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 8),
                      _cardStat('Min Bid', isLocked ? '🔒 Hidden' : formatCurrency(minBid)),
                      Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 8),
                      _cardStat('Min Raise', isLocked ? '🔒 Hidden' : '+${formatCurrency(minRaise)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons (View Details + Bid / Interest / Request or Ended)
                SizedBox(
                  width: double.infinity,
                  child: lotIsEnded
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  AuctionDetailDialog.show(context, lotRoomId);
                                },
                                icon: const Icon(Icons.info_outline_rounded, size: 13),
                                label: const Text('View Details', overflow: TextOverflow.ellipsis),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0288D1),
                                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8.5),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer_off_outlined, size: 13, color: Color(0xFF64748B)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ended',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : canBid
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      AuctionDetailDialog.show(context, lotRoomId);
                                    },
                                    icon: const Icon(Icons.info_outline_rounded, size: 13),
                                    label: const Text('View Details', overflow: TextOverflow.ellipsis),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0288D1),
                                      side: const BorderSide(color: Color(0xFF0288D1)),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LiveAuctionPage(
                                            roomId: lotRoomId,
                                            roomTitle: '$lotTitle (${widget.groupTitle})',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.gavel_rounded, size: 14),
                                    label: const Text('Bid Now', overflow: TextOverflow.ellipsis),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : isLocked
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          AuctionDetailDialog.show(context, lotRoomId);
                                        },
                                        icon: const Icon(Icons.info_outline_rounded, size: 13),
                                        label: const Text('View Details', overflow: TextOverflow.ellipsis),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0288D1),
                                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          EnquiryDialog.show(
                                            context,
                                            '$lotTitle (${widget.groupTitle})',
                                            auctionId: lotRoomId,
                                            isEmdRequired: lotFeeRequired,
                                            emdAmount: lotFeeAmount,
                                          );
                                        },
                                        icon: const Icon(Icons.lock_outline, size: 13),
                                        label: const Text('Request Access', overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEA580C),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          AuctionDetailDialog.show(context, lotRoomId);
                                        },
                                        icon: const Icon(Icons.info_outline_rounded, size: 13),
                                        label: const Text('View Details', overflow: TextOverflow.ellipsis),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0288D1),
                                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          EnquiryDialog.show(
                                            context,
                                            '$lotTitle (${widget.groupTitle})',
                                            auctionId: lotRoomId,
                                            isEmdRequired: lotFeeRequired,
                                            emdAmount: lotFeeAmount,
                                          );
                                        },
                                        icon: const Icon(Icons.touch_app_rounded, size: 14),
                                        label: const Text('Show Interest', overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ───────────────────────────────────────────────────────────
  Widget _buildTimerBadge(bool isLive, bool isEnded, bool isLocked, String timerText) {
    if (isEnded || timerText == 'ENDED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('ENDED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE $timerText',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade800.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('🔒 Private', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0288D1).withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(timerText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatLotCountdown(DateTime? start, DateTime? end, String lotStatus, DateTime now) {
    final nowUtc = now.toUtc();
    if (lotStatus == 'ended' || (end != null && (nowUtc.isAfter(end.toUtc()) || nowUtc.isAtSameMomentAs(end.toUtc())))) {
      return 'ENDED';
    }
    if (lotStatus == 'live' || (start != null && nowUtc.isAfter(start.toUtc()) && end != null && nowUtc.isBefore(end.toUtc()))) {
      if (end != null) {
        final diff = end.toUtc().difference(nowUtc);
        if (!diff.isNegative && diff > Duration.zero) {
          final hours = diff.inHours.toString().padLeft(2, '0');
          final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
          final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
          return '$hours:$mins:$secs';
        }
      }
      return 'LIVE';
    }
    if (start != null && nowUtc.isBefore(start.toUtc())) {
      final diff = start.toUtc().difference(nowUtc);
      if (diff.inDays > 0) {
        return '${diff.inDays}d ${(diff.inHours % 24)}h';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ${(diff.inMinutes % 60)}m';
      } else {
        final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return '$mins:$secs';
      }
    }
    return 'Upcoming';
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 145,
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
      ),
    );
  }

  Widget _summaryPill(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF059669)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }

  Widget _cardStat(String label, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── AuctionDetailDialog (Single Room) ────────────────────────────────────────

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
            final images = (item?['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
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

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (images.isNotEmpty) ...[
                        ImageSlideshowBox(
                          images: images,
                          width: double.infinity,
                          height: 180,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        description,
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      ),
                      const SizedBox(height: 16),
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
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
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
