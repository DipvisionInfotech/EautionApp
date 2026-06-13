import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/gemini_info_dialog.dart';
import '../widgets/enquiry_dialog.dart';

class ClassifiedPage extends StatefulWidget {
  const ClassifiedPage({super.key});

  @override
  State<ClassifiedPage> createState() => _ClassifiedPageState();
}

class _ClassifiedPageState extends State<ClassifiedPage> {
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
              activePage: 'Classified',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () {},
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
                    'Classified',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSearchSection(screenWidth),
                  const SizedBox(height: 30),
                  _buildClassifiedGrid(screenWidth),
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
                _searchDropdown('Select Category', ['Agri Commodity', 'Mobiles', 'Electronics']),
                const SizedBox(height: 10),
                _searchDropdown('Location', ['Delhi', 'Mumbai', 'Wardha']),
                const SizedBox(height: 10),
                _searchInput('Classified Id/Title'),
                const SizedBox(height: 10),
                _searchButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _searchDropdown('Select Category', ['Agri Commodity', 'Mobiles', 'Electronics'])),
                const SizedBox(width: 10),
                Expanded(child: _searchDropdown('Location', ['Delhi', 'Mumbai', 'Wardha'])),
                const SizedBox(width: 10),
                Expanded(child: _searchInput('Classified Id/Title')),
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

  Widget _buildClassifiedGrid(double screenWidth) {
    int crossAxisCount = screenWidth > 1100 ? 3 : (screenWidth > 600 ? 2 : 1);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 2,
      itemBuilder: (context, index) {
        return _buildClassifiedCard(index);
      },
    );
  }

  void _viewDetail(Map<String, String> item) {
    EnquiryDialog.show(context, item['title']!);
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

  Widget _buildClassifiedCard(int index) {
    final items = [
      {
        'title': 'Water Affected Rice',
        'image': 'https://images.unsplash.com/photo-1586201327693-866199f12179?auto=format&fit=crop&w=500&q=60',
        'qty': '4925 Kg',
        'price': '45',
        'location': 'Wardha'
      },
      {
        'title': 'Water Affected Mobiles',
        'image': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=500&q=60',
        'qty': '28 Pieces',
        'price': '225000',
        'location': 'Delhi'
      },
    ];
    final item = items[index % items.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Image.network(
              item['image']!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                _cardRow('Quantity', item['qty']!),
                _cardRow('Price', item['price']!),
                _cardRow('', item['location']!, showLabel: false),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _viewDetail(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View Detail'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardRow(String label, String value, {bool showLabel = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (showLabel) Text('$label : ', style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
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
            leading: const Icon(Icons.gavel),
            title: const Text('Auction'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auction');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Classified'),
            onTap: () => Navigator.pop(context),
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
