import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:e_auction/widgets/login_dialog.dart';
import 'package:e_auction/widgets/gemini_info_dialog.dart';
import 'package:e_auction/services/api_service.dart';

class Header extends StatefulWidget {
  final VoidCallback? onAboutUsTap;
  final VoidCallback? onHomeTap;
  final VoidCallback? onAuctionTap;
  final VoidCallback? onClassifiedTap;
  final VoidCallback? onContactUsTap;
  final String activePage;

  const Header({
    super.key,
    this.onAboutUsTap,
    this.onHomeTap,
    this.onAuctionTap,
    this.onClassifiedTap,
    this.onContactUsTap,
    this.activePage = 'Home',
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  bool _isLoggedIn = false;
  String? _userName;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService.getAccessToken();
    if (token != null) {
      final profile = await ApiService.getProfile();
      if (profile['success'] == true && mounted) {
        setState(() {
          _isLoggedIn = true;
          _userProfile = profile['data'];
          _userName = profile['data']['full_name'];
        });
      } else if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _userProfile = null;
          _userName = 'Profile';
        });
      }
    } else if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _userName = null;
        _userProfile = null;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.clearTokens();
    await _checkLoginStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    }
  }

  void _showProfileDialog() {
    if (_userProfile == null) {
      GeminiInfoDialog.show(
        context,
        'Profile Information',
        'Your login token is valid. Unable to load profile details from server at this moment.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String selectedDocType = 'aadhaar';
        bool isUploading = false;
        String? uploadError;

        return StatefulBuilder(
          builder: (context, setState) {
            final kycVerified = _userProfile!['kyc_verified'] == true;

            return AlertDialog(
              title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileRow('Name', _userProfile!['full_name'] ?? 'N/A'),
                    const Divider(),
                    _profileRow('Email', _userProfile!['email'] ?? 'N/A'),
                    const Divider(),
                    _profileRow('Phone', _userProfile!['phone'] ?? 'N/A'),
                    const Divider(),
                    _profileRow('Role', (_userProfile!['role'] ?? 'N/A').toString().toUpperCase()),
                    const Divider(),
                    _profileRow(
                      'KYC Status',
                      kycVerified ? 'VERIFIED' : 'PENDING REVIEW / UNVERIFIED',
                      color: kycVerified ? Colors.green : Colors.orange,
                    ),
                    const Divider(),
                    if (!kycVerified) ...[
                      const SizedBox(height: 15),
                      const Text(
                        'Upload KYC Document',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedDocType,
                        decoration: const InputDecoration(
                          labelText: 'Document Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            setState(() {
                              selectedDocType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (isUploading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                              );
                              if (result != null) {
                                setState(() {
                                  isUploading = true;
                                  uploadError = null;
                                });
                                
                                List<int> fileBytes;
                                String fileName = result.files.single.name;
                                
                                if (kIsWeb) {
                                  fileBytes = result.files.single.bytes!;
                                } else {
                                  fileBytes = await io.File(result.files.single.path!).readAsBytes();
                                }
                                
                                final res = await ApiService.uploadKYCDocument(
                                  selectedDocType,
                                  fileBytes,
                                  fileName,
                                );
                                
                                if (res['success'] == true) {
                                  await _checkLoginStatus();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('KYC Document uploaded successfully!')),
                                    );
                                    Navigator.pop(context);
                                  }
                                } else {
                                  setState(() {
                                    uploadError = res['error']?.toString() ?? 'Upload failed';
                                  });
                                }
                              }
                            } catch (e) {
                              setState(() {
                                uploadError = 'Error picking/uploading file: $e';
                              });
                            } finally {
                              setState(() {
                                isUploading = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Pick & Upload Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        ),
                      if (uploadError != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          uploadError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _profileRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          // Logo
          InkWell(
            onTap: widget.onHomeTap,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.green, Colors.yellow],
                    ),
                  ),
                  child: const Icon(Icons.handshake, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seal The Deal',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    const Text(
                      'Streamlining Salvage',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile) const Spacer(),
          // Navigation
          if (!isMobile)
            Row(
              children: [
                _navItem(context, 'Home', active: widget.activePage == 'Home', onTap: widget.onHomeTap),
                _navItem(context, 'About Us', active: widget.activePage == 'About Us', onTap: widget.onAboutUsTap),
                _navItem(context, 'Auction', active: widget.activePage == 'Auction', onTap: widget.onAuctionTap),
                _navItem(context, 'Classified', active: widget.activePage == 'Classified', onTap: widget.onClassifiedTap),
                _navItem(context, 'Contact Us', active: widget.activePage == 'Contact Us', onTap: widget.onContactUsTap),
              ],
            ),
          if (!isMobile) const Spacer(),
          // Auth
          Row(
            children: [
              if (_isLoggedIn) ...[
                _authItem(context, Icons.person, _userName ?? 'Profile', onTap: _showProfileDialog),
                SizedBox(width: isMobile ? 10 : 15),
                _authItem(context, Icons.logout, 'Logout', onTap: _logout),
              ] else ...[
                _authItem(context, Icons.lock, 'Login', onTap: () async {
                  final loggedIn = await LoginDialog.show(context);
                  if (loggedIn) {
                    _checkLoginStatus();
                  }
                }),
                SizedBox(width: isMobile ? 10 : 15),
                _authItem(context, Icons.person_add, 'Register', onTap: () => Navigator.pushNamed(context, '/register')),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        GeminiInfoDialog.show(
          context,
          title,
          'Welcome to the $title section. Here you can find detailed information about our services and how we can help you with your salvage and auction needs.',
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.blue : Colors.black87,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 2,
                width: 20,
                color: Colors.blue,
              )
          ],
        ),
      ),
    );
  }

  Widget _authItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 5),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
