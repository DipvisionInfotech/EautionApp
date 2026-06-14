import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/auction_section.dart';

class AuctionPage extends StatefulWidget {
  const AuctionPage({super.key});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
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
                horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upcoming Auctions',
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
    int crossAxisCount = screenWidth > 1200 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 220,
        crossAxisSpacing: 25,
        mainAxisSpacing: 25,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
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
