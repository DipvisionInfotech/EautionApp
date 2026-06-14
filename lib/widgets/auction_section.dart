import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';
import 'enquiry_dialog.dart';

class AuctionSection extends StatelessWidget {
  const AuctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 40.0 : 20.0,
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
              itemBuilder: (context, index) => SizedBox(
                height: 460,
                child: _auctionCardForIndex(index),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 1500 ? 4 : (screenWidth > 1100 ? 3 : 2),
                childAspectRatio: screenWidth > 1500 ? 1.05 : (screenWidth > 1100 ? 0.95 : 1.1),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: 4,
              itemBuilder: (context, index) => _auctionCardForIndex(index),
            ),
          if (isMobile) ...[
            const SizedBox(height: 30),
            Center(
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/auction'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View All Auctions'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _auctionCardForIndex(int index) {
    final auctions = [
      {
        'title': 'STD-GR-410 | Fire Affected Loom Machines, MS & Plastic Scrap, Yarn on Beam, Cot.',
        'image': 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=800&q=80',
        'type': 'Group Auction',
        'start': '16 Jun 2026 16:00 PM',
        'end': '16 Jun 2026 17:00 PM',
        'qty': 'Various'
      },
      {
        'title': 'STD-GR-411 | Plant & Machinery, Building MS, Printing Cylinders, Racks/Furniture, Aluminium Cables.',
        'image': 'https://images.unsplash.com/photo-1504917595217-d4dc5ebe6122?auto=format&fit=crop&w=800&q=80',
        'type': 'Group Auction',
        'start': '19 Jun 2026 16:00 PM',
        'end': '19 Jun 2026 17:00 PM',
        'qty': 'Various'
      },
      {
        'title': 'STD-PR-2052 | Damaged MS Trusses and Purlins',
        'image': 'https://images.unsplash.com/photo-1533035353720-f1c6a75cd8ab?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '16 Jun 2026 16:00 PM',
        'end': '16 Jun 2026 17:00 PM',
        'qty': '22,000 Kg'
      },
      {
        'title': 'STD-PR-2053 | Fire affected 10 Nos. of Loom Machine',
        'image': 'https://images.unsplash.com/photo-1558444479-c8f010b49862?auto=format&fit=crop&w=800&q=80',
        'type': 'Private Auction',
        'start': '16 Jun 2026 16:00 PM',
        'end': '16 Jun 2026 17:00 PM',
        'qty': '25,850 Kg'
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

class AuctionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                InkWell(
                  onTap: () {
                    GeminiInfoDialog.show(context, 'Auction Image', 'Viewing high-resolution image for $title.');
                  },
                  child: Hero(
                    tag: 'auction-$title',
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 160,
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text('Image unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF0288D1)),
                        const SizedBox(width: 4),
                        Text(
                          'Starts in 2D 16H',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: type.contains('Private') ? const Color(0xFF1E293B) : const Color(0xFF0288D1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _detailRow(Icons.calendar_today_outlined, 'Schedule', '$start - $end'),
                    const SizedBox(height: 8),
                    _detailRow(Icons.inventory_2_outlined, 'Quantity', qty),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              GeminiInfoDialog.show(context, 'Details', 'Complete auction specs for $title');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: const Text('View Detail', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => EnquiryDialog.show(context, title),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Show Interest', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: value, style: const TextStyle(color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
