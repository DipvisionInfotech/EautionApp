import 'package:flutter/material.dart';
import 'enquiry_dialog.dart';
import '../services/api_service.dart';

class ClassifiedSection extends StatefulWidget {
  const ClassifiedSection({super.key});

  @override
  State<ClassifiedSection> createState() => _ClassifiedSectionState();
}

class _ClassifiedSectionState extends State<ClassifiedSection> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    final result = await ApiService.getClassifieds();
    if (mounted) {
      setState(() {
        _items = result['success'] == true
            ? ((result['data']['results'] as List<dynamic>?) ?? []).take(3).toList()
            : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20.0,
        vertical: 60.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8BC34A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'DIRECT DEALS',
                      style: TextStyle(
                        color: Color(0xFF689F38),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Classified Listings',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/classified'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('See All Listings'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0288D1),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF8BC34A)),
              ),
            )
          else if (_items.isEmpty)
            _buildEmptyState(context)
          else
            LayoutBuilder(builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 1500
                  ? 4
                  : (constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1));

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 380,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _classifiedCard(context, _items[index]);
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.list_alt_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No classified listings yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/classified'),
              child: const Text('Browse All Listings →'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classifiedCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Untitled';
    final qty = item['quantity']?.toString() ?? '';
    final priceDisplay = item['price_display']?.toString().isNotEmpty == true
        ? item['price_display'].toString()
        : item['price_per_unit'] != null
            ? '₹${item['price_per_unit']}'
            : 'Contact for price';
    final location = item['location']?.toString() ?? '';
    final images = item['images'] as List<dynamic>?;
    // Dashboard shows thumbnails — images list here has no signed URLs (include_images=False)
    // so we show a placeholder; full URLs available on detail page
    final hasImage = images != null && images.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                hasImage
                    ? Image.network(
                        images![0].toString(),
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _imagePlaceholder();
                        },
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
                if (location.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF8BC34A)),
                          const SizedBox(width: 4),
                          Text(location,
                              style: const TextStyle(
                                  color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    if (qty.isNotEmpty) _detailRow(Icons.inventory_2_outlined, 'Quantity', qty),
                    if (qty.isNotEmpty) const SizedBox(height: 8),
                    _detailRow(Icons.payments_outlined, 'Price', priceDisplay),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8BC34A), Color(0xFF689F38)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8BC34A).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => EnquiryDialog.show(context, title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Enquire Now',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Color(0xFFCBD5E1), size: 40),
          SizedBox(height: 6),
          Text('No image', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
