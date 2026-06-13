import 'package:flutter/material.dart';
import 'package:e_auction/widgets/login_dialog.dart';
import 'package:e_auction/widgets/gemini_info_dialog.dart';

class Header extends StatelessWidget {
  final VoidCallback? onAboutUsTap;
  final VoidCallback? onHomeTap;
  final VoidCallback? onAuctionTap;
  final VoidCallback? onClassifiedTap;
  final VoidCallback? onContactUsTap;
  final String activePage;

  const Header({
    super.key,
    this.onAboutUsTap,
    this.onHomeTap,
    this.onAuctionTap,
    this.onClassifiedTap,
    this.onContactUsTap,
    this.activePage = 'Home',
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          // Logo
          InkWell(
            onTap: onHomeTap,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.green, Colors.yellow],
                    ),
                  ),
                  child: const Icon(Icons.handshake, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seal The Deal',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    const Text(
                      'Streamlining Salvage',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile) const Spacer(),
          // Navigation
          if (!isMobile)
            Row(
              children: [
                _navItem(context, 'Home', active: activePage == 'Home', onTap: onHomeTap),
                _navItem(context, 'About Us', active: activePage == 'About Us', onTap: onAboutUsTap),
                _navItem(context, 'Auction', active: activePage == 'Auction', onTap: onAuctionTap),
                _navItem(context, 'Classified', active: activePage == 'Classified', onTap: onClassifiedTap),
                _navItem(context, 'Contact Us', active: activePage == 'Contact Us', onTap: onContactUsTap),
              ],
            ),
          if (!isMobile) const Spacer(),
          // Auth
          Row(
            children: [
              _authItem(context, Icons.lock, 'Login', onTap: () => LoginDialog.show(context)),
              SizedBox(width: isMobile ? 10 : 15),
              _authItem(context, Icons.person, 'Register', onTap: () => Navigator.pushNamed(context, '/register')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        GeminiInfoDialog.show(
          context,
          title,
          'Welcome to the $title section. Here you can find detailed information about our services and how we can help you with your salvage and auction needs.',
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.blue : Colors.black87,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 2,
                width: 20,
                color: Colors.blue,
              )
          ],
        ),
      ),
    );
  }

  Widget _authItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 5),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
