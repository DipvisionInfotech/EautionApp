import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'gemini_info_dialog.dart';
import 'enquiry_dialog.dart';

class AuctionSection extends StatelessWidget {
  const AuctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20.0,
        vertical: 60.0,
      ),
      child: Column(
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
                      color: const Color(0xFF0288D1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EXCLUSIVE DEALS',
                      style: TextStyle(
                        color: Color(0xFF0288D1),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upcoming Auctions',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (!isMobile)
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
          if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) => _auctionCardForIndex(index),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 1200 ? 2 : 1,
                mainAxisExtent: 220,
                crossAxisSpacing: 30,
                mainAxisSpacing: 30,
              ),
              itemCount: 4,
              itemBuilder: (context, index) => _auctionCardForIndex(index),
            ),
        ],
      ),
    );
  }

  Widget _auctionCardForIndex(int index) {
    final auctions = [
      {
        'title': 'STD-PR-2059 | Fire Affected Approx. 1,00,000 Kg of Plant & Machinery on "as is where is" basis.',
        'image': 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '19 Jun 2026 04:00 PM',
        'end': '19 Jun 2026 05:00 PM',
        'qty': '100000kg'
      },
      {
        'title': 'STD-PR-2060 | Fire Affected approx. 40,000 Kg of Building (Heavy & Light MS Structure) on "as is where is" basis.',
        'image': 'https://images.unsplash.com/photo-1504917595217-d4dc5ebe6122?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '19 Jun 2026 04:00 PM',
        'end': '19 Jun 2026 05:00 PM',
        'qty': '40000kg'
      },
      {
        'title': 'STD-PR-2061 | Fire Affected approx. 30,000 Kg of Printing Cylinders (MS) on "as is where is" basis.',
        'image': 'https://images.unsplash.com/photo-1533035353720-f1c6a75cd8ab?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '19 Jun 2026 04:00 PM',
        'end': '19 Jun 2026 05:00 PM',
        'qty': '30000kg'
      },
      {
        'title': 'STD-PR-2062 | Fire Affected approx. 10,000 Kg of Racks & Furniture on "per kg" basis.',
        'image': 'https://images.unsplash.com/photo-1558444479-c8f010b49862?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '19 Jun 2026 04:00 PM',
        'end': '19 Jun 2026 05:00 PM',
        'qty': '10000kg'
      },
    ];
    final auction = auctions[index % auctions.length];
    return AuctionCard(
      title: auction['title']!,
      imageUrl: auction['image']!,
      type: auction['type']!,
      start: auction['start']!,
      end: auction['end']!,
      qty: auction['qty']!,
    );
  }
}

class AuctionCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String type;
  final String start;
  final String end;
  final String qty;

  const AuctionCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.type,
    required this.start,
    required this.end,
    required this.qty,
  });

  @override
  State<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<AuctionCard> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;
  String _statusText = 'Loading...';
  Color _statusColor = const Color(0xFF555555);
  bool _isUpcoming = true;

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
    try {
      DateFormat format = DateFormat("dd MMM yyyy hh:mm a");
      DateTime startTime = format.parse(widget.start);
      DateTime endTime = format.parse(widget.end);
      
      _updateTime(startTime, endTime);
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTime(startTime, endTime);
      });
    } catch (e) {
      debugPrint("Error parsing date: $e");
      setState(() {
        _statusText = 'Invalid Date';
      });
    }
  }

  void _updateTime(DateTime startTime, DateTime endTime) {
    if (!mounted) return;
    
    final now = DateTime.now();
    
    setState(() {
      if (now.isBefore(startTime)) {
        _statusText = 'Starts In : ';
        _statusColor = const Color(0xFF555555);
        _timeLeft = startTime.difference(now);
        _isUpcoming = true;
      } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
        _statusText = 'LIVE NOW';
        _statusColor = Colors.red;
        _timeLeft = endTime.difference(now);
        _isUpcoming = false;
      } else {
        _statusText = 'Auction Ended';
        _statusColor = Colors.grey;
        _timeLeft = Duration.zero;
        _isUpcoming = false;
      }
    });
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
                      errorBuilder: (context, error, stackTrace) => Container(
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
                        _infoRow('Start Time', widget.start),
                        _infoRow('End Time', widget.end),
                        _infoRow('Quantity', widget.qty),
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
                          if (_statusText != 'Auction Ended' && _statusText != 'Invalid Date') ...[
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
                          _actionButton(context, 'View', const Color(0xFF03A9F4), () {
                            GeminiInfoDialog.show(context, 'Details', 'Complete auction specs for ${widget.title}');
                          }, isExtraSmall),
                          const SizedBox(width: 6),
                          _actionButton(context, _statusText == 'LIVE NOW' ? 'Bid Now' : 'Show Interest', _statusText == 'LIVE NOW' ? Colors.red : const Color(0xFF8BC34A), () {
                            EnquiryDialog.show(context, widget.title);
                          }, isExtraSmall),
                        ],
                      ),
                    ],
                  );
                }
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
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF777777), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
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
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: isExtraSmall ? 9 : 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, Color color, VoidCallback onPressed, bool isExtraSmall) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isExtraSmall ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: isExtraSmall ? 10 : 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
