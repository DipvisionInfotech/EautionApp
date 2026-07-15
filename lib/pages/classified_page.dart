import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/enquiry_dialog.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';

class ClassifiedPage extends StatefulWidget {
  const ClassifiedPage({super.key});

  @override
  State<ClassifiedPage> createState() => _ClassifiedPageState();
}

class _ClassifiedPageState extends State<ClassifiedPage> {
  List<dynamic> _listings = [];
  List<dynamic> _categories = [];
  List<dynamic> _cities = [];
  bool _isLoading = true;
  String? _selectedCategorySlug;
  String? _selectedLocation;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getCategories(),
      ApiService.getCities(),
      ApiService.getClassifieds(
        categorySlug: _selectedCategorySlug,
        location: _selectedLocation,
        search: _searchController.text.isEmpty ? null : _searchController.text,
      ),
    ]);

    if (mounted) {
      setState(() {
        _categories = results[0] as List<dynamic>;
        _cities = results[1] as List<dynamic>;
        final classified = results[2] as Map<String, dynamic>;
        _listings = classified['success'] == true
            ? (classified['data']['results'] as List<dynamic>? ?? [])
            : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const CustomDrawer(activePage: 'Classified') : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'Classified',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () {},
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.1 : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Classified Listings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSearchSection(screenWidth),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(60),
                          child: CircularProgressIndicator(color: Color(0xFF0288D1)),
                        ))
                      : _listings.isEmpty
                          ? _buildEmptyState()
                          : _buildClassifiedGrid(screenWidth),
                ],
              ),
            ),
            Footer(
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(double screenWidth) {
    bool isSmall = screenWidth < 900;
    final categoryItems = [
      const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
      ..._categories.map((c) => DropdownMenuItem<String>(
            value: c['slug']?.toString(),
            child: Text(c['name']?.toString() ?? ''),
          )),
    ];

    final List<String> locList = _cities.isNotEmpty
        ? _cities.where((c) => c['is_active'] == true).map((c) => c['name']?.toString() ?? '').toList()
        : _listings
            .map((l) => l['location']?.toString() ?? '')
            .where((l) => l.isNotEmpty)
            .toSet()
            .toList();
    
    locList.sort();

    final locationItems = [
      const DropdownMenuItem<String>(value: null, child: Text('All Locations')),
      ...locList.map((loc) => DropdownMenuItem<String>(value: loc, child: Text(loc))),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: isSmall
          ? Column(
              children: [
                _categoryDropdown(categoryItems),
                const SizedBox(height: 10),
                _locationDropdown(locationItems),
                const SizedBox(height: 10),
                _searchInput(),
                const SizedBox(height: 10),
                _searchButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _categoryDropdown(categoryItems)),
                const SizedBox(width: 10),
                Expanded(child: _locationDropdown(locationItems)),
                const SizedBox(width: 10),
                Expanded(child: _searchInput()),
                const SizedBox(width: 10),
                _searchButton(),
              ],
            ),
    );
  }

  Widget _categoryDropdown(List<DropdownMenuItem<String>> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedCategorySlug,
          hint: const Text('Select Category', style: TextStyle(fontSize: 14)),
          items: items,
          onChanged: (v) => setState(() => _selectedCategorySlug = v),
        ),
      ),
    );
  }

  Widget _locationDropdown(List<DropdownMenuItem<String>> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedLocation,
          hint: const Text('Location', style: TextStyle(fontSize: 14)),
          items: items,
          onChanged: (v) => setState(() => _selectedLocation = v),
        ),
      ),
    );
  }

  Widget _searchInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Search listings...',
          hintStyle: TextStyle(fontSize: 14),
        ),
        onSubmitted: (_) => _loadData(),
      ),
    );
  }

  Widget _searchButton() {
    return ElevatedButton(
      onPressed: _loadData,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: const Text('Search'),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No listings found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or check back later.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassifiedGrid(double screenWidth) {
    int crossAxisCount = screenWidth > 1500 ? 4 : (screenWidth > 1100 ? 3 : (screenWidth > 700 ? 2 : 1));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: screenWidth > 700 ? 420 : 400,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _listings.length,
      itemBuilder: (context, index) {
        return _buildClassifiedCard(_listings[index], screenWidth);
      },
    );
  }

  Widget _buildClassifiedCard(Map<String, dynamic> item, double screenWidth) {
    final itemId = item['id']?.toString() ?? '';  // Extract the classified item ID
    final imageUrl = (item['images'] as List?)?.isNotEmpty == true
        ? item['images'][0].toString()
        : null;
    final title = item['title']?.toString() ?? 'Untitled';
    final qty = item['quantity']?.toString() ?? '';
    final priceDisplay = item['price_display']?.toString().isNotEmpty == true
        ? item['price_display'].toString()
        : item['price_per_unit'] != null
            ? '₹${item['price_per_unit']}'
            : 'Contact for price';
    final location = item['location']?.toString() ?? '';

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
                imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: screenWidth > 700 ? 180 : 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(screenWidth),
                      )
                    : _imagePlaceholder(screenWidth),
                if (location.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF0288D1)),
                          const SizedBox(width: 4),
                          Text(location, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.bold)),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A), height: 1.2),
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
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [Color(0xFF0288D1), Color(0xFF01579B)]),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0288D1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => EnquiryDialog.show(context, title, auctionId: itemId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Enquire Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _imagePlaceholder(double screenWidth) {
    return Container(
      height: screenWidth > 700 ? 180 : 160,
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Color(0xFFCBD5E1), size: 48)),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


}
