import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/auction_section.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';

class AuctionPage extends StatefulWidget {
  const AuctionPage({super.key});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
  List<AuctionDisplayItem> _items = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;

  String? _selectedCategorySlug;
  String? _selectedStatus;
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
      ApiService.getRooms(),
    ]);

    if (mounted) {
      final categoriesResult = results[0] as List<dynamic>;
      final roomsResult = results[1] as Map<String, dynamic>;

      List<Map<String, dynamic>> rawRooms = roomsResult['success'] == true
          ? ((roomsResult['data']['results'] as List<dynamic>?) ?? [])
              .where((r) => r is Map)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList()
          : [];

      List<AuctionDisplayItem> displayItems = AuctionDisplayItem.groupRooms(rawRooms);

      // Apply category filter
      if (_selectedCategorySlug != null) {
        displayItems = displayItems.where((item) {
          if (item.isGroup) {
            return item.lots.any((l) => l['category'] == _selectedCategorySlug);
          }
          return item.singleRoom?['category'] == _selectedCategorySlug;
        }).toList();
      }

      // Apply search filter
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        displayItems = displayItems.where((item) {
          if (item.title.toLowerCase().contains(q)) return true;
          if (item.groupId.toLowerCase().contains(q)) return true;
          if (item.roomId.toLowerCase().contains(q)) return true;
          if (item.isGroup) {
            return item.lots.any((l) {
              final lotTitle = l['title']?.toString().toLowerCase() ?? '';
              final itemName = (l['item'] as Map?)?['name']?.toString().toLowerCase() ?? '';
              final lotId = l['id']?.toString().toLowerCase() ?? '';
              return lotTitle.contains(q) || itemName.contains(q) || lotId.contains(q);
            });
          }
          return false;
        }).toList();
      }

      setState(() {
        _categories = categoriesResult;
        _items = displayItems;
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
      drawer: isMobile ? const CustomDrawer(activePage: 'Auction') : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'Auction',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () {},
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.08 : 20,
                vertical: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upcoming Auctions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSearchSection(screenWidth),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(color: Color(0xFF0288D1)),
                    ))
                  else if (_items.isEmpty)
                    _buildEmptyState()
                  else
                    _buildAuctionGrid(screenWidth),
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
                _searchInput(),
                const SizedBox(height: 10),
                _searchButton(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _categoryDropdown(categoryItems)),
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
          hintText: 'Auction ID / Title',
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
            Icon(Icons.gavel_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No auctions found',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Try adjusting your filters or check back soon.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuctionGrid(double screenWidth) {
    bool isMobile = screenWidth < 800;
    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final item = _items[index];
          if (item.isGroup) {
            return GroupAuctionCard(item: item);
          }
          return AuctionCard.fromDisplayItem(item);
        },
      );
    }
    int crossAxisCount = screenWidth > 1200 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 250,
        crossAxisSpacing: 25,
        mainAxisSpacing: 25,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        if (item.isGroup) {
          return GroupAuctionCard(item: item);
        }
        return AuctionCard.fromDisplayItem(item);
      },
    );
  }
}
