import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/file_helper.dart';
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
        List<dynamic> kycDocs = [];
        bool isLoadingDocs = true;
        PlatformFile? chosenFile;
        List<int>? chosenBytes;

        final allDocTypes = [
          {'type': 'aadhaar', 'label': 'Aadhaar Card'},
          {'type': 'pan', 'label': 'PAN Card'},
          {'type': 'passport', 'label': 'Passport / ID Proof'},
          {'type': 'gst', 'label': 'GST Registration'},
          {'type': 'other', 'label': 'Other Document / Cheque'},
        ];

        String getLabelForType(String type) {
          final found = allDocTypes.firstWhere(
            (item) => item['type'] == type,
            orElse: () => {'type': type, 'label': type.toUpperCase()},
          );
          return found['label'] ?? type.toUpperCase();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final kycVerified = _userProfile!['kyc_verified'] == true;
            final isAdmin = _userProfile!['role'] == 'admin';

            // Fetch document list once
            if (isLoadingDocs && !isAdmin) {
              isLoadingDocs = false;
              ApiService.getKYCStatus().then((res) {
                if (res['success'] == true && res['data'] != null && mounted) {
                  setState(() {
                    kycDocs = res['data']['documents'] ?? [];
                  });
                }
              });
            }

            final uploadedDocTypes = kycDocs.map((d) => d['type']?.toString().toLowerCase()).toSet();
            final availableDocTypes = allDocTypes.where((item) => !uploadedDocTypes.contains(item['type'])).toList();

            if (availableDocTypes.isNotEmpty && !availableDocTypes.any((item) => item['type'] == selectedDocType)) {
              selectedDocType = availableDocTypes.first['type']!;
            }

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
                    if (!isAdmin) ...[
                      _profileRow(
                        'KYC Status',
                        kycVerified ? 'VERIFIED' : 'PENDING REVIEW / UNVERIFIED',
                        color: kycVerified ? Colors.green : Colors.orange,
                      ),
                      const Divider(),
                    ],
                    if (!isAdmin && kycDocs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Uploaded KYC Documents (1 per category):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 8),
                      ...kycDocs.map((doc) {
                        final typeKey = doc['type']?.toString().toLowerCase() ?? '';
                        final docLabel = getLabelForType(typeKey);
                        final fileName = doc['file_name']?.toString() ?? '${typeKey}_doc.pdf';
                        final size = ((doc['size'] ?? 0) / 1024).toStringAsFixed(0);
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.description, color: Color(0xFF1A237E), size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(docLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                    Text('$fileName • $size KB', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.download, color: Color(0xFF1A237E), size: 20),
                                tooltip: 'Download Document',
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Downloading $docLabel...')),
                                  );
                                  final res = await ApiService.downloadKYCDocument(doc['type']);
                                  if (res['success'] == true && res['bytes'] != null) {
                                    downloadFileBytes(res['bytes'], res['filename'] ?? fileName);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$docLabel downloaded successfully!')),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res['error']?.toString() ?? 'Download failed')),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Delete Document',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Document'),
                                      content: Text('Are you sure you want to delete your $docLabel?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final res = await ApiService.deleteKYCDocument(doc['type']);
                                    if (res['success'] == true) {
                                      final newStatus = await ApiService.getKYCStatus();
                                      if (newStatus['success'] == true && mounted) {
                                        setState(() {
                                          kycDocs = newStatus['data']['documents'] ?? [];
                                        });
                                      }
                                      await _checkLoginStatus();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Document deleted successfully!')),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(res['error']?.toString() ?? 'Delete failed')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                    ],
                    if (!kycVerified && !isAdmin) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Upload KYC Document',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Only 1 file allowed per category. Allowed formats: PDF, JPG, PNG (Max 10MB)',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),

                      if (availableDocTypes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'All 5 KYC document categories have been uploaded. To re-upload a document, delete the existing one first.',
                                  style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          value: selectedDocType,
                          decoration: const InputDecoration(
                            labelText: 'Select Category to Upload',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: availableDocTypes.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['type']!,
                              child: Text(item['label']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedDocType = val;
                                chosenFile = null;
                                chosenBytes = null;
                                uploadError = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // File chosen preview OR Pick Button
                        if (chosenFile != null && chosenBytes != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.attach_file, color: Color(0xFF1D4ED8), size: 20),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        chosenFile!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${(chosenFile!.size / 1024).toStringAsFixed(0)} KB',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ready to upload for: ${getLabelForType(selectedDocType)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            setState(() {
                                              isUploading = true;
                                              uploadError = null;
                                            });

                                            try {
                                              final res = await ApiService.uploadKYCDocument(
                                                selectedDocType,
                                                chosenBytes!,
                                                chosenFile!.name,
                                              );

                                              if (res['success'] == true) {
                                                await _checkLoginStatus();
                                                final newStatus = await ApiService.getKYCStatus();
                                                if (newStatus['success'] == true && mounted) {
                                                  setState(() {
                                                    kycDocs = newStatus['data']['documents'] ?? [];
                                                    chosenFile = null;
                                                    chosenBytes = null;
                                                  });
                                                }
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('${getLabelForType(selectedDocType)} uploaded successfully!')),
                                                  );
                                                }
                                              } else {
                                                setState(() {
                                                  uploadError = res['error']?.toString() ?? 'Upload failed';
                                                });
                                              }
                                            } catch (e) {
                                              setState(() {
                                                uploadError = 'Error uploading document: $e';
                                              });
                                            } finally {
                                              setState(() {
                                                isUploading = false;
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.cloud_upload, size: 18),
                                          label: const Text('Confirm & Upload'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            chosenFile = null;
                                            chosenBytes = null;
                                            uploadError = null;
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                checkFilePickerInit();
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                                  withData: true,
                                );
                                if (result != null) {
                                  final file = result.files.single;
                                  const maxSizeBytes = 10 * 1024 * 1024;
                                  if (file.size > maxSizeBytes) {
                                    setState(() {
                                      uploadError = 'File size must be under 10MB.';
                                    });
                                    return;
                                  }

                                  final bytes = await getPlatformFileBytes(file);
                                  setState(() {
                                    chosenFile = file;
                                    chosenBytes = bytes;
                                    uploadError = null;
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  uploadError = 'Error picking file: $e';
                                });
                              }
                            },
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('Choose File to Upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ],
                      ],
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
                    color: Color(0xFF0288D1),
                  ),
                  child: const Icon(Icons.handshake, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slick Salvage',
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
                if (_isLoggedIn && _userProfile != null && _userProfile!['role'] == 'seller') ...[
                  _navItem(context, 'My Auctions', active: widget.activePage == 'My Auctions', onTap: () {
                    Navigator.pushNamed(context, '/seller-auctions');
                  }),
                  _navItem(context, 'My Enquiries', active: widget.activePage == 'My Enquiries', onTap: () {
                    Navigator.pushNamed(context, '/seller-enquiries');
                  }),
                ] else ...[
                  _navItem(context, 'Auction', active: widget.activePage == 'Auction', onTap: widget.onAuctionTap),
                  if (_isLoggedIn && _userProfile != null && _userProfile!['role'] == 'bidder')
                    _navItem(context, 'Past Auctions', active: widget.activePage == 'Past Auctions', onTap: () {
                      Navigator.pushNamed(context, '/past-auctions');
                    }),
                  _navItem(context, 'Classified', active: widget.activePage == 'Classified', onTap: widget.onClassifiedTap),
                ],
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
