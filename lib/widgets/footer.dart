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
            const Column(
              children: [
                Text('© Copyright 2026 Slick Salvage. All rights reserved.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          else
            const Row(
              children: [
                Expanded(child: Text('© Copyright 2026 Slick Salvage. All rights reserved.', style: TextStyle(color: Colors.grey, fontSize: 12))),
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
            'Terms and Conditions\n\nWelcome to Slick Salvage. By accessing this website, you agree to comply with and be bound by the following terms and conditions of use. The content of the pages of this website is for your general information and use only. It is subject to change without notice.\n\nYour use of any information or materials on this website is entirely at your own risk, for which we shall not be liable. It shall be your own responsibility to ensure that any products, services or information available through this website meet your specific requirements.\n\nUnauthorized use of this website may give rise to a claim for damages and/or be a criminal offense.',
          ),
        ),
        _footerLink(
          context,
          'Privacy Policy',
          onTap: () => GeminiInfoDialog.show(
            context,
            'Privacy Policy',
            'Privacy Policy\n\nYour privacy is important to us. It is Slick Salvage\'s policy to respect your privacy regarding any information we may collect from you across our website. We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent.\n\nWe don’t share any personally identifying information publicly or with third-parties, except when required to by law. Our website may link to external sites that are not operated by us. Please be aware that we have no control over the content and practices of these sites.',
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
        _contactItem(context, Icons.business, 'Slick Salvage LLP'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.location_on, 'SLICK SALVAGE LLP HOUSE NO 1/A KH. NO. 31/9, G/F, BLK-D, DEEP VIHAR, Badli (North West Delhi), ROHINI SECTOR 24, Delhi, North West Delhi- 110042, Delhi, India'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.phone, '+91 9311219522'),
        const SizedBox(height: 15),
        _contactItem(context, Icons.email, 'info@slicksalvage.com'),
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
            'About Slick Salvage e-Auctions\n\nSlick Salvage is a premier online marketplace specializing in forward e-Auctions for insurance salvage, commercial assets, and industrial disposal. We connect insurance companies and corporate clients with certified buyers to ensure high realization value and transparency in disposal.\n\nKey Advantages of Slick Salvage\n\nWe provide a secure, audited bidding platform with real-time bidding updates, automated credential management, and detailed ledger trails. Bidders can participate in auctions from anywhere in India with full transparency.',
          ),
          _discoverItem(
            context,
            'Salvage Services',
            'Commercial Liquidations & Salvage Sales\n\nSlick Salvage provides comprehensive disposal services for a wide variety of salvage, including automobiles, machinery, metals, electronics, and warehouse stock. We handle the entire cataloging, bidding interest verification, and document collection process.\n\nOur Services:\n\n* Audited transparent bidding rooms\n* KYC-verified buyer network\n* Automated bidder verification and approval\n* Quick payout and delivery tracking for sellers',
          ),
          _discoverItem(
            context,
            'Bidding Rules',
            'Slick Salvage Bidding Guidelines\n\nTo maintain the integrity of our marketplace, all participants must follow our bidding rules:\n\n* KYC Verification: All buyers must complete their profile and submit valid identity proof (Aadhaar/PAN) for admin review.\n* Registration Fee: Certain auctions require a refundable or adjustable registration fee to filter serious participants.\n* Atomic Bidding: All bids are processed atomically through our real-time engine to prevent overlaps or ghost bids.\n* Binding Offers: Every bid placed is a legally binding commitment to purchase the asset at the specified value.',
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
