import 'package:flutter/material.dart';
import 'gemini_info_dialog.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  String? selectedCategory;
  String? selectedType;
  String? selectedLocation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        SizedBox(
          height: screenWidth > 600 ? 550 : 650,
          width: double.infinity,
          child: Image.network(
            'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=2070&q=80',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1A237E),
              child: const Center(child: Icon(Icons.image, size: 100, color: Colors.white24)),
            ),
          ),
        ),
        Container(
          height: screenWidth > 600 ? 550 : 650,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFB3E5FC)],
                  ).createShader(bounds),
                  child: Text(
                    'Precision Salvage & Auction Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth > 600 ? 42 : 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Connecting transparent buyers with verified salvage opportunities across India.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: screenWidth > 600 ? 18 : 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (screenWidth > 800)
                        Row(
                          children: [
                            Expanded(child: _searchDropdown('Category', [
                              'Agri Commodity', 'Agriculture', 'Aluminium', 'Automotive',
                              'Building Material', 'Cables', 'Chemicals', 'Electronics',
                              'Metal Scrap', 'Plant & Machinery', 'Textiles', 'Vehicle'
                            ], selectedCategory, (val) => setState(() => selectedCategory = val))),
                            const SizedBox(width: 12),
                            Expanded(child: _searchDropdown('Listing Type', ['Auction', 'Classified'], selectedType, (val) => setState(() => selectedType = val))),
                            const SizedBox(width: 12),
                            Expanded(child: _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad', 'Pune', 'Bengaluru', 'Chennai'], selectedLocation, (val) => setState(() => selectedLocation = val))),
                          ],
                        )
                      else ...[
                        _searchDropdown('Category', ['Agri Commodity', 'Agriculture', 'Aluminium', 'Automotive', 'Building Material', 'Cables', 'Chemicals', 'Electronics', 'Metal Scrap', 'Plant & Machinery', 'Textiles', 'Vehicle'], selectedCategory, (val) => setState(() => selectedCategory = val)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _searchDropdown('Listing Type', ['Auction', 'Classified'], selectedType, (val) => setState(() => selectedType = val))),
                            const SizedBox(width: 12),
                            Expanded(child: _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad', 'Pune', 'Bengaluru', 'Chennai'], selectedLocation, (val) => setState(() => selectedLocation = val))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: screenWidth > 600 ? 3 : 1,
                            child: _searchInput('Search by Auction ID or Product Title...', _searchController),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _searchButton(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (screenWidth > 600) ...[
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statItem('5000+', 'Active Users'),
                      _verticalDivider(),
                      _statItem('₹50Cr+', 'Trade Value'),
                      _verticalDivider(),
                      _statItem('100%', 'Verified Leads'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3));
  }

  Widget _searchInput(String hint, TextEditingController controller) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _searchButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0288D1), Color(0xFF01579B)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0288D1).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          GeminiInfoDialog.show(
            context,
            'Search Results',
            'Searching for: "${_searchController.text}"\nCategory: ${selectedCategory ?? "All"}\nType: ${selectedType ?? "All"}\nLocation: ${selectedLocation ?? "All"}',
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _searchDropdown(String hint, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: options.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
