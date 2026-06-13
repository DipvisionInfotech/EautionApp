import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/gemini_info_dialog.dart';
import '../widgets/enquiry_dialog.dart';

class AuctionPage extends StatefulWidget {
  const AuctionPage({super.key});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
  String? selectedCategory;
  String? selectedType;
  String? selectedLocation;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? _buildDrawer(context) : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'Auction',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () {},
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.1 : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auction',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSearchSection(screenWidth),
                  const SizedBox(height: 30),
                  _buildAuctionGrid(screenWidth),
                  const SizedBox(height: 40),
                  _buildDiscoverMore(context),
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

  Widget _buildSearchSection(double screenWidth) {
    bool isSmall = screenWidth < 900;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: isSmall
          ? Column(
              children: [
                _searchDropdown('Select Category', ['Agri Commodity', 'MS Scrap', 'Textiles', 'Scrap']),
                const SizedBox(height: 10),
                _searchDropdown('Listing Type', ['Auction', 'Classified']),
                const SizedBox(height: 10),
                _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad']),
                const SizedBox(height: 10),
                _searchInput('Auction Id/Title'),
                const SizedBox(height: 10),
                _searchButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _searchDropdown('Select Category', ['Agri Commodity', 'MS Scrap', 'Textiles', 'Scrap'])),
                const SizedBox(width: 10),
                Expanded(child: _searchDropdown('Listing Type', ['Auction', 'Classified'])),
                const SizedBox(width: 10),
                Expanded(child: _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad'])),
                const SizedBox(width: 10),
                Expanded(child: _searchInput('Auction Id/Title')),
                const SizedBox(width: 10),
                _searchButton(),
              ],
            ),
    );
  }

  Widget _searchDropdown(String hint, List<String> options) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {},
        ),
      ),
    );
  }

  Widget _searchInput(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _searchButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: const Text('Search'),
    );
  }

  Widget _buildAuctionGrid(double screenWidth) {
    int crossAxisCount = screenWidth > 1100 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: screenWidth > 600 ? 1.8 : 1.1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return _buildAuctionCard(index);
      },
    );
  }

  void _viewDetail(Map<String, String> auction) {
    GeminiInfoDialog.show(
      context,
      auction['title']!,
      'Auction Detail for: ${auction['title']}\n\nQuantity: ${auction['qty']}\nStart: ${auction['start']}\nEnd: ${auction['end']}\nCategory: ${auction['cat']}\n\nThis is a detailed view of the auction item. More information can be added here once provided by the backend.',
    );
  }

  void _showInterest(Map<String, String> auction) {
    EnquiryDialog.show(context, auction['title']!);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAuctionCard(int index) {
    final auctions = [
      {
        'title': 'Approx. 22,000 Kg of Damaged MS Trusses and Purlins on "Per Kg" Basis',
        'image': 'https://plus.unsplash.com/premium_photo-1661962383790-a3594042217c?auto=format&fit=crop&w=500&q=60',
        'start': '16 Jun 2026 04:00 PM',
        'end': '16 Jun 2026 05:00 PM',
        'qty': '22000 kg',
        'cat': 'M S Scrap'
      },
      {
        'title': 'Fire Affected Approx. 25,850 Kg of Fire affected 10 Nos. of Loom Machine (MS + Pla...',
        'image': 'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?auto=format&fit=crop&w=500&q=60',
        'start': '16 Jun 2026 04:00 PM',
        'end': '16 Jun 2026 05:00 PM',
        'qty': '25,850 Kg',
        'cat': 'Scrap'
      },
      {
        'title': 'Fire & Water Affected Approx. 7,800 Kg of Yarn on Beem on "Per Kg" Basis',
        'image': 'https://images.unsplash.com/photo-1558346490-a72e53ae2d4f?auto=format&fit=crop&w=500&q=60',
        'start': '16 Jun 2026 04:00 PM',
        'end': '16 Jun 2026 05:00 PM',
        'qty': '7,800 Kg',
        'cat': 'Textiles'
      },
      {
        'title': 'Fire & Water Affected Approx. 2,650 Kg of Cotton Fabric',
        'image': 'https://images.unsplash.com/photo-1528469133744-672527221d66?auto=format&fit=crop&w=500&q=60',
        'start': '16 Jun 2026 04:00 PM',
        'end': '16 Jun 2026 05:00 PM',
        'qty': '2,650 Kg',
        'cat': 'Fabric'
      },
    ];
    final auction = auctions[index % auctions.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    auction['image']!,
                    width: 140,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 140,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    children: [
                      _rowInfo('Start Time', auction['start']!),
                      _rowInfo('Start Time', auction['end']!), // Reusing labels as per screenshot
                      _rowInfo('Quantity', auction['qty']!),
                      _rowInfo('Auction Category', auction['cat']!),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            auction['title']!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn('View', const Color(0xFF03A9F4), () => _viewDetail(auction)),
              const SizedBox(width: 10),
              _actionBtn('Show Interest', const Color(0xFF8BC34A), () => _showInterest(auction)),
            ],
          ),
        ],
      ),
    );
  }


  Widget _rowInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildDiscoverMore(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text('Discover more', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          _discoverItem(context, 'E-Commerce Services'),
          const Divider(),
          _discoverItem(context, 'e-Auction'),
          const Divider(),
          _discoverItem(context, 'Auctions'),
        ],
      ),
    );
  }

  Widget _discoverItem(BuildContext context, String title) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        String content = "";
        if (title == 'e-Auction') {
          content = 'Understanding the E-Auction Process\n\nE-auctions represent a modern approach to buying and selling goods and services online...';
        } else if (title == 'E-Commerce Services') {
          content = 'Understanding E-commerce Services\n\nE-commerce services encompass a wide range of tools and platforms...';
        } else {
          content = 'Understanding Auctions: A Buyer\'s Guide\n\nAuctions represent a unique marketplace where goods and services are sold to the highest bidder...';
        }
        GeminiInfoDialog.show(context, title, content);
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1A237E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Seal The Deal', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Streamlining Salvage', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about-us');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Classified'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/classified');
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/contact-us');
            },
          ),
        ],
      ),
    );
  }
}
