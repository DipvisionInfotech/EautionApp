import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';
import 'enquiry_dialog.dart';

class ClassifiedSection extends StatelessWidget {
  const ClassifiedSection({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.all(screenWidth > 600 ? 40.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Classified Listings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/classified');
                },
                child: const Row(
                  children: [
                    Text('View All'),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _classifiedCard(context, 'Water Affected Rice', '4925 Kg', '45', 'Wardha', 'https://images.unsplash.com/photo-1586201327111-9f43a5b63547?auto=format&fit=crop&w=500&q=60'),
                _classifiedCard(context, 'Water Affected Mobiles', '28 Pieces', '225000', 'Delhi', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=500&q=60'),
                _classifiedCard(context, 'MS Distribution Panel', '500 Kg', '120', 'Mumbai', 'https://images.unsplash.com/photo-1558444479-c8f010b49862?auto=format&fit=crop&w=500&q=60'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _classifiedCard(BuildContext context, String title, String qty, String price, String location, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                GeminiInfoDialog.show(context, 'Classified Image', 'Viewing high-resolution image of $title. Our classified listings provide detailed visual information for all items.');
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text('Quantity : $qty', style: const TextStyle(fontSize: 14)),
                Text('Price : $price', style: const TextStyle(fontSize: 14)),
                Text(location, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    EnquiryDialog.show(context, title);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8BC34A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text('View Detail'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
