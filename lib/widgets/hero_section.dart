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
          height: screenWidth > 600 ? 500 : 600,
          width: double.infinity,
          child: Image.network(
            'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=2070&q=80',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.blueGrey,
              child: const Center(child: Icon(Icons.image, size: 100, color: Colors.white24)),
            ),
          ),
        ),
        Container(
          height: screenWidth > 600 ? 500 : 600,
          width: double.infinity,
          color: Colors.black.withOpacity(0.4),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Search classified and auctions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth > 600 ? 32 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _searchDropdown('Select category', [
                        'Agri Commodity',
                        'Agriculture',
                        'Aluminium',
                        'Automotive',
                        'Building Material',
                        'Cables',
                        'Chemicals',
                        'Electronics',
                        'Metal Scrap',
                        'Plant & Machinery',
                        'Textiles',
                        'Vehicle'
                      ], selectedCategory, (val) => setState(() => selectedCategory = val)),
                      const SizedBox(height: 15),
                      if (screenWidth > 600)
                        Row(
                          children: [
                            Expanded(child: _searchDropdown('Listing Type', ['Auction', 'Classified'], selectedType, (val) => setState(() => selectedType = val))),
                            const SizedBox(width: 15),
                            Expanded(child: _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad', 'Pune', 'Bengaluru', 'Chennai'], selectedLocation, (val) => setState(() => selectedLocation = val))),
                          ],
                        )
                      else ...[
                        _searchDropdown('Listing Type', ['Auction', 'Classified'], selectedType, (val) => setState(() => selectedType = val)),
                        const SizedBox(height: 15),
                        _searchDropdown('Location', ['Delhi', 'Mumbai', 'Ahmedabad', 'Pune', 'Bengaluru', 'Chennai'], selectedLocation, (val) => setState(() => selectedLocation = val)),
                      ],
                      const SizedBox(height: 15),
                      if (screenWidth > 600)
                        Row(
                          children: [
                            Expanded(
                              child: _searchInput('Action Id/Title', _searchController),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _searchButton(),
                            ),
                          ],
                        )
                      else ...[
                        _searchInput('Action Id/Title', _searchController),
                        const SizedBox(height: 15),
                        _searchButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchInput(String hint, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _searchButton() {
    return ElevatedButton(
      onPressed: () {
        GeminiInfoDialog.show(
          context,
          'Search Results',
          'Searching for: "${_searchController.text}"\nCategory: ${selectedCategory ?? "All"}\nType: ${selectedType ?? "All"}\nLocation: ${selectedLocation ?? "All"}\n\nCurrently, we are processing your search criteria. In the full version, this will filter the listings below based on your selections.',
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: const Text('Search'),
    );
  }

  Widget _searchDropdown(String hint, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: value,
          items: options.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
