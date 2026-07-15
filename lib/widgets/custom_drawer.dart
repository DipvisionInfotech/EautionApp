import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomDrawer extends StatefulWidget {
  final String activePage;
  const CustomDrawer({super.key, required this.activePage});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService.getAccessToken();
    if (token != null) {
      final profile = await ApiService.getProfile();
      if (profile['success'] == true && mounted) {
        setState(() {
          _isLoggedIn = true;
          _userProfile = profile['data'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBidder = _isLoggedIn && _userProfile != null && _userProfile!['role'] == 'bidder';

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
                Text(
                  'Seal The Deal',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Streamlining Salvage',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerItem(
            context,
            Icons.home,
            'Home',
            widget.activePage == 'Home',
            () {
              Navigator.pop(context);
              if (widget.activePage != 'Home') {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          _drawerItem(
            context,
            Icons.info,
            'About Us',
            widget.activePage == 'About Us',
            () {
              Navigator.pop(context);
              if (widget.activePage != 'About Us') {
                Navigator.pushNamed(context, '/about-us');
              }
            },
          ),
          _drawerItem(
            context,
            Icons.gavel,
            'Auction',
            widget.activePage == 'Auction',
            () {
              Navigator.pop(context);
              if (widget.activePage != 'Auction') {
                Navigator.pushNamed(context, '/auction');
              }
            },
          ),
          if (isBidder)
            _drawerItem(
              context,
              Icons.history,
              'Past Auctions',
              widget.activePage == 'Past Auctions',
              () {
                Navigator.pop(context);
                if (widget.activePage != 'Past Auctions') {
                  Navigator.pushNamed(context, '/past-auctions');
                }
              },
            ),
          _drawerItem(
            context,
            Icons.list_alt,
            'Classified',
            widget.activePage == 'Classified',
            () {
              Navigator.pop(context);
              if (widget.activePage != 'Classified') {
                Navigator.pushNamed(context, '/classified');
              }
            },
          ),
          _drawerItem(
            context,
            Icons.contact_support,
            'Contact Us',
            widget.activePage == 'Contact Us',
            () {
              Navigator.pop(context);
              if (widget.activePage != 'Contact Us') {
                Navigator.pushNamed(context, '/contact-us');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black87,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }
}
