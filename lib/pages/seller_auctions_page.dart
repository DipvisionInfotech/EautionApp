import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';
import 'live_auction_page.dart';
import '../utils/date_utils.dart';
import '../utils/number_to_words.dart';

class SellerAuctionsPage extends StatefulWidget {
  const SellerAuctionsPage({super.key});

  @override
  State<SellerAuctionsPage> createState() => _SellerAuctionsPageState();
}

class _SellerAuctionsPageState extends State<SellerAuctionsPage> {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  Map<String, dynamic>? _sellerSettings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ApiService.getProfile(),
      ApiService.getRooms(), // Seller gets only their linked rooms from the backend!
    ]);

    if (mounted) {
      final profileResult = results[0] as Map<String, dynamic>;
      final roomsResult = results[1] as Map<String, dynamic>;

      if (profileResult['success'] == true) {
        _sellerSettings = profileResult['data']['seller_settings'];
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

    final viewAuctionsEnabled = _sellerSettings == null || 
        _sellerSettings!['view_auctions_enabled'] != false;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const CustomDrawer(activePage: 'My Auctions') : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'My Auctions',
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
                    'My Auctions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View and spectate auctions associated with your products.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  if (!viewAuctionsEnabled)
                    _buildDisabledState("Viewing auctions is currently disabled for your account. Please contact the administrator.")
                  else if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_rooms.isEmpty)
                    _buildEmptyState()
                  else
                    _buildAuctionsGrid(screenWidth),
                ],
              ),
            ),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.red.shade700, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade900, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.gavel, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Auctions Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'No auction rooms have been created for your items yet. Contact the administrator to create one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionsGrid(double screenWidth) {
    int crossAxisCount = screenWidth > 1200 ? 3 : (screenWidth > 700 ? 2 : 1);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return _buildAuctionCard(room);
      },
    );
  }

  Widget _buildAuctionCard(dynamic room) {
    final title = room['title'] ?? 'Unnamed Auction';
    final status = (room['status'] ?? 'upcoming').toString().toUpperCase();
    final category = room['category'] ?? '-';
    
    final item = room['item'] ?? {};
    final minBid = item['min_bid'] ?? 0;
    final minRaise = item['min_raise'] ?? 0;
    final images = item['images'] as List<dynamic>?;
    final imageUrl = (images != null && images.isNotEmpty) 
        ? images[0].toString() 
        : 'https://placehold.co/600x400/png';

    final scheduledStart = room['scheduled_start'] != null
        ? DateTimeUtils.parseUtc(room['scheduled_start'].toString())
        : null;

    final spectateEnabled = _sellerSettings == null || 
        _sellerSettings!['spectate_live_enabled'] != false;
        
    final resultsEnabled = _sellerSettings == null || 
        _sellerSettings!['view_results_enabled'] != false;

    Color statusColor;
    if (status == 'LIVE') {
      statusColor = Colors.red;
    } else if (status == 'UPCOMING') {
      statusColor = Colors.orange;
    } else if (status == 'ENDED') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.grey;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image with Status Badge
          Stack(
            children: [
              Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image, size: 50, color: Colors.grey.shade400),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'LIVE' ? 'LIVE NOW' : status,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          
          // Card Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  
                  // Auction Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _smallStat('Reserve Price', formatCurrency(minBid)),
                      _smallStat('Min Raise', formatCurrency(minRaise)),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Action buttons
                  if (status == 'LIVE' && spectateEnabled)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.remove_red_eye, size: 16),
                        label: const Text('Spectate Live Room'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveAuctionPage(
                                roomId: room['id'] ?? room['_id'],
                                roomTitle: title,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  else if (status == 'ENDED' && resultsEnabled && room['winning_bid'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🎉 WINNING BID',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(room['winning_bid']),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          scheduledStart != null
                              ? 'Starts: ${scheduledStart.day}/${scheduledStart.month} at ${scheduledStart.hour}:${scheduledStart.minute.toString().padLeft(2, '0')}'
                              : 'Upcoming',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}
