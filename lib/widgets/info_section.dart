import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sealthedeal is an online platform that offers a wide range of scrap materials for sale through e-auctions. Our company is committed to providing a transparent and convenient way for buyers to purchase scrap materials from various industries, Power Generating Companies, and more.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 15),
          const Text(
            'Our website provides comprehensive information on the available scrap material, including detailed descriptions, images, and auction schedules. Buyers can register with us easily and participate in e-auctions from the comfort of their own location, eliminating the need for physical presence.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 30),
          Container(
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
                _discoverItem(
                  context,
                  'e-Auction',
                  'Understanding the E-Auction Process\n\nE-auctions, or electronic auctions, represent a modern approach to buying and selling goods and services online. They leverage internet technology to facilitate the bidding process, allowing participants from diverse locations to compete for items in real-time. This method offers a streamlined and often transparent way to acquire items, ranging from consumer goods to industrial equipment and even government contracts.\n\nKey Advantages for Buyers\n\nFor potential buyers, e-auctions present several compelling benefits. They often provide access to a wider selection of items than traditional methods, potentially including unique or hard-to-find goods. The competitive nature of bidding can sometimes lead to securing items below their typical market value, offering significant cost savings. Furthermore, the convenience of participating from anywhere with an internet connection eliminates geographical barriers and reduces the time and expense associated with physical auctions.',
                ),
                const Divider(),
                _discoverItem(
                  context,
                  'E-Commerce Services',
                  'Understanding E-commerce Services\n\nE-commerce services encompass a wide range of tools and platforms designed to facilitate online business transactions. These services are essential for anyone looking to sell products or services over the internet, providing the necessary infrastructure for everything from building a website to processing payments and managing inventory.\n\nShopify: A Popular All-in-One Platform\n\nShopify is a widely-used e-commerce platform that offers a comprehensive suite of tools for creating and managing an online store. It provides customizable templates, secure payment processing, inventory management, and marketing tools, all within a single interface.\n\nWooCommerce: Flexibility for WordPress Users\n\nWooCommerce is a free, open-source e-commerce plugin specifically designed for WordPress websites. It allows users to transform their existing WordPress site into a...',
                ),
                const Divider(),
                _discoverItem(
                  context,
                  'Auctions',
                  'Understanding Auctions: A Buyer\'s Guide\n\nAuctions represent a unique marketplace where goods and services are sold to the highest bidder. They can cover a vast range of items, from fine art and antiques to real estate, vehicles, and industrial equipment. Understanding the auction process, including how bidding works and the potential fees involved, is crucial for anyone considering making a purchase. Auctions can offer opportunities to acquire items at potentially competitive prices, but they also require careful research and a clear understanding of the rules before participating.\n\nExploring Online Auction Platforms: eBay\n\neBay is perhaps the most well-known online auction platform, connecting buyers and sellers globally. It allows individuals and businesses to list items for auction, setting a starting price and duration. Buyers place bids, and the highest bidder wins the item at the end of the specified period. eBay also offers \'Buy It Now\' options, blurring the lines between traditional auctions and fixed-price retail. Understanding the bidding increments, shipping costs, and seller feedback is essential when using eBay for purchases.\n\nSpecialized Auctions: Sotheby\'s and Fine Art\n\nFor high-value items like fine art, antiques, and luxury goods, auction houses like Sotheby\'s operate both online and in physical salerooms. These auctions are often highly curated, featuring items with significant provenance and value. Participating in these requires registration, potential financial vetting, and understanding specific',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoverItem(BuildContext context, String title, String content) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        GeminiInfoDialog.show(context, title, content);
      },
    );
  }
}
