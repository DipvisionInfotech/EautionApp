import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/hero_section.dart';
import '../widgets/auction_section.dart';
import '../widgets/classified_section.dart';
import '../widgets/info_section.dart';
import '../widgets/footer.dart';
import '../widgets/gemini_info_dialog.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
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
            _drawerItem(context, Icons.home, 'Home', onTap: () => Navigator.pop(context)),
            _drawerItem(context, Icons.info, 'About Us', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about-us');
            }),
            _drawerItem(context, Icons.gavel, 'Auction', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auction');
            }),
            _drawerItem(context, Icons.list_alt, 'Classified', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/classified');
            }),
            _drawerItem(context, Icons.contact_support, 'Contact Us', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/contact-us');
            }),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'Home',
              onHomeTap: () {},
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            const HeroSection(),
            const AuctionSection(),
            const ClassifiedSection(),
            const InfoSection(),
            Footer(
              onHomeTap: () {},
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap ?? () {
        Navigator.pop(context);
        GeminiInfoDialog.show(
          context,
          title,
          'You selected $title from the menu. This section provides access to specific platform features and information. Some features may require you to be logged in.',
        );
      },
    );
  }
}
