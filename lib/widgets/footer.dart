import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';

class Footer extends StatelessWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onAboutUsTap;

  const Footer({super.key, this.onHomeTap, this.onAboutUsTap});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Container(
      color: const Color(0xFF1E293B),
      padding: EdgeInsets.all(screenWidth > 600 ? 40 : 20),
      child: Column(
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _aboutSection(context),
                const SizedBox(height: 30),
                _quickLinksSection(context),
                const SizedBox(height: 30),
                _contactSection(context),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _aboutSection(context)),
                Expanded(child: _quickLinksSection(context)),
                Expanded(flex: 2, child: _contactSection(context)),
                if (screenWidth > 1100) Expanded(child: _discoverMoreSection(context)),
              ],
            ),
          if (isMobile || (screenWidth <= 1100)) ...[
            const SizedBox(height: 30),
            _discoverMoreSection(context),
          ],
          const SizedBox(height: 40),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          if (isMobile)
            Column(
              children: [
                const Text('© Copyright 2026 Sealthedeal. All rights reserved.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                const Text('Developed By: Kodeberg Labs', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('© Copyright 2026 Sealthedeal. All rights reserved.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                Expanded(child: Text('Developed By: Kodeberg Labs', textAlign: TextAlign.end, style: TextStyle(color: Colors.grey, fontSize: 12))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _aboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About Us', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Text(
          'We provide an online marketplace to sell the salvage under Insurance Claims or reputed clients through forward e-Auction.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _socialIcon(context, Icons.facebook),
            const SizedBox(width: 10),
            _socialIcon(context, Icons.link),
          ],
        ),
      ],
    );
  }

  Widget _quickLinksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Links', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _footerLink(context, 'Home', onTap: onHomeTap ?? () => Navigator.pushNamed(context, '/')),
        _footerLink(context, 'About Us', onTap: onAboutUsTap ?? () => Navigator.pushNamed(context, '/about-us')),
        _footerLink(context, 'Auction', onTap: () => Navigator.pushNamed(context, '/auction')),
        _footerLink(context, 'Classified', onTap: () => Navigator.pushNamed(context, '/classified')),
        _footerLink(context, 'Contact Us', onTap: () => Navigator.pushNamed(context, '/contact-us')),
        _footerLink(
          context,
          'Terms & Condition',
          onTap: () => GeminiInfoDialog.show(
            context,
            'Terms & Condition',
            'Terms and Conditions\n\nWelcome to Sealthedeal. By accessing this website, you agree to comply with and be bound by the following terms and conditions of use. The content of the pages of this website is for your general information and use only. It is subject to change without notice.\n\nYour use of any information or materials on this website is entirely at your own risk, for which we shall not be liable. It shall be your own responsibility to ensure that any products, services or information available through this website meet your specific requirements.\n\nUnauthorized use of this website may give rise to a claim for damages and/or be a criminal offense.',
          ),
        ),
        _footerLink(
          context,
          'Privacy Policy',
          onTap: () => GeminiInfoDialog.show(
            context,
            'Privacy Policy',
            'Privacy Policy\n\nYour privacy is important to us. It is Sealthedeal\'s policy to respect your privacy regarding any information we may collect from you across our website. We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent.\n\nWe don’t share any personally identifying information publicly or with third-parties, except when required to by law. Our website may link to external sites that are not operated by us. Please be aware that we have no control over the content and practices of these sites.',
          ),
        ),
      ],
    );
  }

  Widget _contactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Us', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _contactItem(context, Icons.location_on, 'Delhi Office - Kings Mall, Office No. 2, 5th Floor, Rohini Sector 10, New Delhi - 110085'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.location_on, 'Mumbai office - Haware Infotech Park, Office No: 1108, 11th Floor, Sector 30A, Vashi, Navi Mumbai, Maharashtra - 400703.'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.phone, '9709709992'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.email, 'info@sealthedeal.co.in'),
      ],
    );
  }

  Widget _socialIcon(BuildContext context, IconData icon) {
    return InkWell(
      onTap: () {
        GeminiInfoDialog.show(
          context,
          'Social Media',
          'Follow us on our social media platforms to stay updated with the latest auctions and salvage opportunities. We are active on Facebook and LinkedIn.',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _footerLink(BuildContext context, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap ?? () {
          GeminiInfoDialog.show(
            context,
            title,
            'This is a placeholder for the $title section. You can replace this with actual detailed information regarding the platform\'s $title.',
          );
        },
        child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }

  Widget _contactItem(BuildContext context, IconData icon, String text) {
    return InkWell(
      onTap: () {
        GeminiInfoDialog.show(context, 'Contact Detail', text);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _discoverMoreSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Discover more',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _discoverItem(
            context,
            'e-Auction',
            'Understanding the E-Auction Process\n\nE-auctions, or electronic auctions, represent a modern approach to buying and selling goods and services online. They leverage internet technology to facilitate the bidding process, allowing participants from diverse locations to compete for items in real-time. This method offers a streamlined and often transparent way to acquire items, ranging from consumer goods to industrial equipment and even government contracts.\n\nKey Advantages for Buyers\n\nFor potential buyers, e-auctions present several compelling benefits. They often provide access to a wider selection of items than traditional methods, potentially including unique or hard-to-find goods. The competitive nature of bidding can sometimes lead to securing items below their typical market value, offering significant cost savings. Furthermore, the convenience of participating from anywhere with an internet connection eliminates geographical barriers and reduces the time and expense associated with physical auctions.',
          ),
          _discoverItem(
            context,
            'E-Commerce Services',
            'Understanding E-commerce Services\n\nE-commerce services encompass a wide range of tools and platforms designed to facilitate online business transactions. These services are essential for anyone looking to sell products or services over the internet, providing the necessary infrastructure for everything from building a website to processing payments and managing inventory.\n\nShopify: A Popular All-in-One Platform\n\nShopify is a widely-used e-commerce platform that offers a comprehensive suite of tools for creating and managing an online store. It provides customizable templates, secure payment processing, inventory management, and marketing tools, all within a single interface.\n\nWooCommerce: Flexibility for WordPress Users\n\nWooCommerce is a free, open-source e-commerce plugin specifically designed for WordPress websites. It allows users to transform their existing WordPress site into a...',
          ),
          _discoverItem(
            context,
            'Auctions',
            'Understanding Auctions: A Buyer\'s Guide\n\nAuctions represent a unique marketplace where goods and services are sold to the highest bidder. They can cover a vast range of items, from fine art and antiques to real estate, vehicles, and industrial equipment. Understanding the auction process, including how bidding works and the potential fees involved, is crucial for anyone considering making a purchase. Auctions can offer opportunities to acquire items at potentially competitive prices, but they also require careful research and a clear understanding of the rules before participating.\n\nExploring Online Auction Platforms: eBay\n\neBay is perhaps the most well-known online auction platform, connecting buyers and sellers globally. It allows individuals and businesses to list items for auction, setting a starting price and duration. Buyers place bids, and the highest bidder wins the item at the end of the specified period. eBay also offers \'Buy It Now\' options, blurring the lines between traditional auctions and fixed-price retail. Understanding the bidding increments, shipping costs, and seller feedback is essential when using eBay for purchases.\n\nSpecialized Auctions: Sotheby\'s and Fine Art\n\nFor high-value items like fine art, antiques, and luxury goods, auction houses like Sotheby\'s operate both online and in physical salerooms. These auctions are often highly curated, featuring items with significant provenance and value. Participating in these requires registration, potential financial vetting, and understanding specific',
          ),
        ],
      ),
    );
  }

  Widget _discoverItem(BuildContext context, String title, String content) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade300),
        Material(
          color: const Color(0xFFF9FAFB),
          child: InkWell(
            onTap: () => GeminiInfoDialog.show(context, title, content),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
