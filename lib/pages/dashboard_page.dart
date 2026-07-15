import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/hero_section.dart';
import '../widgets/auction_section.dart';
import '../widgets/classified_section.dart';
import '../widgets/info_section.dart';
import '../widgets/footer.dart';
import '../widgets/gemini_info_dialog.dart';
import '../widgets/custom_drawer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const CustomDrawer(activePage: 'Home'),
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
}
