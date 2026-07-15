import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/auction_section.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';

class PastAuctionsPage extends StatefulWidget {
  const PastAuctionsPage({super.key});

  @override
  State<PastAuctionsPage> createState() => _PastAuctionsPageState();
}

class _PastAuctionsPageState extends State<PastAuctionsPage> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ApiService.getProfile(),
      ApiService.getRooms(past: true),
    ]);

    if (mounted) {
      final profileResult = results[0] as Map<String, dynamic>;
      final roomsResult = results[1] as Map<String, dynamic>;

      if (profileResult['success'] == true) {
        _currentUserId = profileResult['data']['id']?.toString() ?? 
                         profileResult['data']['_id']?.toString();
      }

      final allRooms = roomsResult['success'] == true
          ? ((roomsResult['data']['results'] as List<dynamic>?) ?? [])
          : [];

      setState(() {
        _rooms = allRooms;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const CustomDrawer(activePage: 'Past Auctions') : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'Past Auctions',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Past Auctions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the history and results of auctions you registered for, bid in, or won.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(color: Color(0xFF0288D1)),
                    ))
                  else if (_rooms.isEmpty)
                    _buildEmptyState()
                  else
                    _buildAuctionGrid(screenWidth),
                ],
              ),
            ),
            Footer(
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No past auctions found',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('You haven\'t participated in any completed auctions yet.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuctionGrid(double screenWidth) {
    int crossAxisCount = screenWidth > 1200 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 235,
        crossAxisSpacing: 25,
        mainAxisSpacing: 25,
      ),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final winnerId = room['winner']?['user_id']?.toString();
        final isUserWinner = _currentUserId != null && winnerId == _currentUserId;

        return _buildPastAuctionCard(room, isUserWinner);
      },
    );
  }

  Widget _buildPastAuctionCard(Map<String, dynamic> room, bool isUserWinner) {
    final item = room['item'] as Map<String, dynamic>?;
    final images = item?['images'] as List<dynamic>?;
    final imageUrl = (images != null && images.isNotEmpty)
        ? images[0].toString()
        : 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=800&q=80';

    final title = room['title']?.toString() ?? 'Untitled Auction';
    final qty = item?['quantity']?.toString() ?? '';
    final minBid = item?['min_bid'] ?? 0;
    
    final finalPrice = room['winner']?['bid_amount'] ?? room['current_bid'] ?? minBid;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      imageUrl,
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
                        _infoRow('Status', room['status']?.toString().toUpperCase() ?? 'ENDED', isBadge: true, isWinner: isUserWinner),
                        _infoRow('Base Price', '₹$minBid'),
                        _infoRow('Final Price', '₹$finalPrice'),
                        if (qty.isNotEmpty) _infoRow('Quantity', qty),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                title,
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
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isUserWinner)
                    const Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, color: Color(0xFF4CAF50), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'You won this auction!',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(Icons.gavel, color: Colors.grey, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Participation Recorded',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ElevatedButton(
                    onPressed: () => AuctionDetailDialog.show(context, room['id']?.toString() ?? ''),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF03A9F4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBadge = false, bool isWinner = false}) {
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
                color: isWinner ? const Color(0xFF4CAF50) : const Color(0xFF78909C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isWinner ? '🏆 WON' : value,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
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
}
