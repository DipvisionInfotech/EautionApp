import 'package:flutter/material.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sealthedeal is an online platform that offers a wide range of scrap materials for sale through e-auctions. Our company is committed to providing a transparent and convenient way for buyers to purchase scrap materials from various industries, Power Generating Companies, and more.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          SizedBox(height: 15),
          Text(
            'Our website provides comprehensive information on the available scrap material, including detailed descriptions, images, and auction schedules. Buyers can register with us easily and participate in e-auctions from the comfort of their own location, eliminating the need for physical presence.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
