import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../widgets/login_dialog.dart';
import '../widgets/gemini_info_dialog.dart';
import '../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _userType = 'Buyer';
  bool _agreeToTerms = false;
  bool _selectAllCategories = false;
  bool _isRegistering = false;
  String _docType = 'aadhaar';
  PlatformFile? _docFile;
  
  List<dynamic> _categories = [];
  String? _selectedCategorySlug;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        GeminiInfoDialog.show(
          context,
          'Action Required',
          'Please agree to the Terms and Conditions to proceed with the registration.',
        );
        return;
      }

      setState(() => _isRegistering = true);

      // Make actual API call to Django
      String apiRole = _userType == 'Buyer' ? 'bidder' : _userType.toLowerCase();
      
      // Determine preferred categories
      List<String>? preferredCats;
      if (_selectAllCategories) {
        preferredCats = _categories.map((c) => c['slug'].toString()).toList();
      } else if (_selectedCategorySlug != null) {
        preferredCats = [_selectedCategorySlug!];
      }

      try {
        final result = await ApiService.register(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
          apiRole,
          phone: _phoneController.text,
          preferredCategories: preferredCats,
        );

        if (result['success']) {
          bool uploadSuccess = true;
          String? uploadError;

          if (_docFile != null) {
            List<int> fileBytes;
            if (kIsWeb) {
              fileBytes = _docFile!.bytes!;
            } else {
              fileBytes = await io.File(_docFile!.path!).readAsBytes();
            }

            final uploadRes = await ApiService.uploadKYCDocument(
              _docType,
              fileBytes,
              _docFile!.name,
            );
            if (uploadRes['success'] != true) {
              uploadSuccess = false;
              uploadError = uploadRes['error']?.toString();
            }
          }

          if (!mounted) return;
          setState(() => _isRegistering = false);

          String infoMsg = 'Thank you for registering with Seal The Deal!\n\nYour account has been created successfully and you are securely logged in.';
          if (_docFile != null) {
            if (uploadSuccess) {
              infoMsg += '\n\nYour KYC document ($_docType) has been uploaded successfully for admin review.';
            } else {
              infoMsg += '\n\nWARNING: KYC document upload failed ($uploadError). You can re-upload it from your Profile page.';
            }
          } else {
            infoMsg += '\n\nNext Steps:\n1. Open your Profile page to upload KYC documents for account verification.\n2. Explore active auctions.';
          }

          GeminiInfoDialog.show(
            context,
            'Registration Successful',
            infoMsg,
          );
        } else {
          if (!mounted) return;
          setState(() => _isRegistering = false);
          
          String errorMsg = 'An error occurred. Please try again.';
          if (result['error'] != null) {
            if (result['error'] is Map) {
              // Extract the first error message from the JSON map
              final Map errors = result['error'];
              if (errors.isNotEmpty) {
                final key = errors.keys.first;
                final value = errors[key];
                errorMsg = '$key: ${value is List ? value.first : value}';
              }
            } else {
              errorMsg = result['error'].toString();
            }
          }
          
          GeminiInfoDialog.show(
            context,
            'Registration Failed',
            errorMsg,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isRegistering = false);
        GeminiInfoDialog.show(
          context,
          'Network Error',
          'Failed to connect to the server. Please ensure the backend is running ($e)',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: '', // No active page highlight for register
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.1 : 20,
                vertical: 40,
              ),
              child: isMobile
                  ? Column(
                      children: [
                        _buildRegisterForm(context),
                        const SizedBox(height: 40),
                        _buildInfoSection(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildRegisterForm(context)),
                        const SizedBox(width: 60),
                        Expanded(flex: 5, child: _buildInfoSection()),
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

  Widget _buildRegisterForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Already have an account? '),
              InkWell(
                onTap: () {
                  LoginDialog.show(context);
                },
                child: const Text(
                  'Log in',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildTextField(
            'Enter your full name',
            controller: _nameController,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your name';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Enter your email',
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Enter your mobile number',
            controller: _phoneController,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your mobile number';
              if (value.length < 10) return 'Please enter a valid mobile number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Enter Password',
            isPassword: true,
            controller: _passwordController,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Text('User Type', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _radioOption('Buyer'),
              _radioOption('Seller'),
              _radioOption('Both'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Select Preferred Category', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Checkbox(
                value: _selectAllCategories,
                onChanged: (v) => setState(() => _selectAllCategories = v!),
              ),
              const Text('Select All'),
            ],
          ),
          const SizedBox(height: 10),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KYC Verification Document (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _docType,
                  decoration: InputDecoration(
                    labelText: 'Document Type',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar Card')),
                    DropdownMenuItem(value: 'pan', child: Text('PAN Card')),
                    DropdownMenuItem(value: 'passport', child: Text('Passport')),
                    DropdownMenuItem(value: 'gst', child: Text('GST Registration')),
                    DropdownMenuItem(value: 'other', child: Text('Other ID')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _docType = val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _docFile == null ? 'No file selected' : 'Selected: ${_docFile!.name}',
                        style: TextStyle(color: _docFile == null ? Colors.grey : Colors.black87, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                        );
                        if (result != null) {
                          final file = result.files.single;
                          const maxSizeBytes = 2 * 1024 * 1024;
                          if (file.size > maxSizeBytes) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File size must be under 2MB.')),
                              );
                            }
                            return;
                          }
                          final ext = file.name.split('.').last.toLowerCase();
                          const allowedExts = ['pdf', 'jpg', 'jpeg', 'png'];
                          if (!allowedExts.contains(ext)) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Only PDF and Image files (.pdf, .jpg, .jpeg, .png) are allowed.')),
                              );
                            }
                            return;
                          }
                          setState(() => _docFile = file);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Choose File', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (v) => setState(() => _agreeToTerms = v!),
              ),
              const Text('I agree to '),
              InkWell(
                onTap: () {},
                child: const Text(
                  'terms and conditions',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isRegistering ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isRegistering
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, {bool isPassword = false, TextEditingController? controller, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: const Color(0xFF0288D1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Text('Loading categories...', style: TextStyle(color: Colors.grey)),
      );
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF0288D1)),
        ),
      ),
      hint: const Text('or Choose category...', style: TextStyle(fontSize: 14, color: Colors.grey)),
      value: _selectedCategorySlug,
      items: _categories.map((c) => DropdownMenuItem<String>(
        value: c['slug'].toString(),
        child: Text(c['name'].toString()),
      )).toList(),
      onChanged: _selectAllCategories ? null : (val) => setState(() => _selectedCategorySlug = val),
      disabledHint: const Text('All categories selected'),
    );
  }

  Widget _radioOption(String value) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _userType,
          onChanged: (v) => setState(() => _userType = v!),
        ),
        Text(value),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1000&q=80'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
        ),
      ),
      padding: const EdgeInsets.all(40),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create account as a user for free !',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 30),
          _BulletPoint('Get access to 150+ private and public auctions.'),
          _BulletPoint('List your classifieds on our website for free.'),
          _BulletPoint('We cover all sorts of category for auctions.'),
          _BulletPoint('Participate in private and public auctions.'),
          _BulletPoint('Place bid on the auctions real time.'),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ],
      ),
    );
  }
}
