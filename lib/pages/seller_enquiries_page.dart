import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import '../services/api_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/gemini_info_dialog.dart';
import '../utils/date_utils.dart';

class SellerEnquiriesPage extends StatefulWidget {
  const SellerEnquiriesPage({super.key});

  @override
  State<SellerEnquiriesPage> createState() => _SellerEnquiriesPageState();
}

class _SellerEnquiriesPageState extends State<SellerEnquiriesPage> {
  List<dynamic> _enquiries = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadEnquiries() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getSellerEnquiries();
    if (mounted) {
      setState(() {
        _enquiries = result['success'] == true ? (result['data'] ?? []) : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _submitNewEnquiry() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final result = await ApiService.submitSellerEnquiry(
        message: _messageController.text,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result['success'] == true) {
          _messageController.clear();
          Navigator.pop(context); // Close dialog
          GeminiInfoDialog.show(
            context,
            'Query Submitted',
            'Your enquiry has been successfully sent to the administrator. We will discuss it soon.',
          );
          _loadEnquiries(); // Reload
        } else {
          GeminiInfoDialog.show(
            context,
            'Error',
            'Failed to submit query. Please try again later.',
          );
        }
      }
    }
  }

  void _showNewEnquiryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Contact Administrator', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send a message to the administrator regarding your products, deals, or account verification queries.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type your query here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Message cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    setDialogState(() => _isSubmitting = true);
                    await _submitNewEnquiry();
                    setDialogState(() => _isSubmitting = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AEEF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Message'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? const CustomDrawer(activePage: 'My Enquiries') : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'My Enquiries',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () => Navigator.pushNamed(context, '/about-us'),
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Enquiries',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Manage and review your communications with the platform team.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showNewEnquiryDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Contact Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00AEEF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_enquiries.isEmpty)
                    _buildEmptyState()
                  else
                    _buildEnquiriesList(),
                ],
              ),
            ),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.mail_outline, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Enquiries Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have not sent any queries to the admin yet. Click "Contact Admin" to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEnquiriesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _enquiries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final enquiry = _enquiries[index];
        final message = enquiry['message'] ?? '';
        final status = (enquiry['status'] ?? 'new').toString().toLowerCase();
        final adminNotes = enquiry['admin_notes'] ?? '';
        final createdAt = enquiry['created_at'] != null
            ? DateTimeUtils.parseUtc(enquiry['created_at'].toString())
            : null;

        Color badgeColor;
        if (status == 'new') {
          badgeColor = Colors.blue;
        } else if (status == 'contacted') {
          badgeColor = Colors.orange;
        } else if (status == 'converted') {
          badgeColor = Colors.green;
        } else {
          badgeColor = Colors.grey;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              if (adminNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADMINISTRATOR RESPONSE:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminNotes,
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
