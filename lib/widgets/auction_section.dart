import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';
import 'enquiry_dialog.dart';

class AuctionSection extends StatelessWidget {
  const AuctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Padding(
      padding: EdgeInsets.all(screenWidth > 600 ? 40.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Auction',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/auction');
                },
                child: const Row(
                  children: [
                    Text('View All'),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                return _auctionCardForIndex(index);
              },
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 1200 ? 3 : 2,
                childAspectRatio: screenWidth > 1200 ? 1.5 : 1.8,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _auctionCardForIndex(index);
              },
            ),
        ],
      ),
    );
  }

  Widget _auctionCardForIndex(int index) {
    final auctions = [
      {
        'title': 'STD-GR-410 | Fire Affected Loom Machines, MS & Plastic Scrap, Yarn on Beam, Cot.',
        'image': 'https://images.unsplash.com/photo-1581092160562-40aa08e78837?auto=format&fit=crop&w=500&q=60',
        'type': 'Group Auction',
        'start': '16 Jun 2026 16:00 PM',
        'end': '16 Jun 2026 17:00 PM',
        'qty': 'Various'
      },
      {
        'title': 'STD-GR-411 | Plant & Machinery, Building MS, Printing Cylinders, Racks/Furniture, Aluminium Cables.',
        'image': 'https://images.unsplash.com/photo-1504384308090-c89e12076d22?auto=format&fit=crop&w=500&q=60',
        'type': 'Group Auction',
        'start': '19 Jun 2026 16:00 PM',
        'end': '19 Jun 2026 17:00 PM',
        'qty': 'Various'
      },
      {
        'title': 'STD-PR-2052 | Damaged MS Trusses and Purlins',
        'image': 'https://images.unsplash.com/photo-1516937941344-00b4e0337589?auto=format&fit=crop&w=500&q=60',
        'type': 'Private Auction',
        'start': '16 Jun 2026 16:00 PM',
        'end': '16 Jun 2026 17:00 PM',
        'qty': '22,000 Kg'
      },
      {
        'title': 'STD-PR-2053 | Fire affected 10 Nos. of Loom Machine',
        'image': 'https://images.unsplash.com/photo-1558444479-c8f010b49862?auto=format&fit=crop&w=500&q=60',
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmall = screenWidth < 500;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  GeminiInfoDialog.show(context, 'Auction Image', 'Viewing high-resolution image for $title. All our auction listings include detailed visual documentation for inspection.');
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: isSmall ? 100 : 120,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: isSmall ? 100 : 120,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  children: [
                    _auctionInfoRow('Auction Type', type, isBadge: true),
                    _auctionInfoRow('Start Time', start),
                    _auctionInfoRow('End Time', end),
                    _auctionInfoRow('Quantity', qty),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Starts In : ', style: TextStyle(fontSize: 12)),
                  _timeBox('2D'),
                  _timeBox('16H'),
                  _timeBox('26M'),
                  _timeBox('1S'),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      GeminiInfoDialog.show(
                        context,
                        'Auction Details: $title',
                        'Auction: $title\nType: $type\nStart: $start\nEnd: $end\nQuantity: $qty\n\nThis auction is scheduled to begin soon. Please ensure you have completed your registration and submitted any required EMD (Earnest Money Deposit) to participate.',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF03A9F4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(60, 35),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      EnquiryDialog.show(context, title);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(100, 35),
                    ),
                    child: const Text('Show Interest', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auctionInfoRow(String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _timeBox(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF03A9F4),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
