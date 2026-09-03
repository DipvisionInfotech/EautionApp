import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'gemini_info_dialog.dart';
import '../services/api_service.dart';
import '../utils/file_helper.dart';
import '../utils/number_to_words.dart';

class EnquiryDialog extends StatefulWidget {
  final String auctionTitle;
  final String? auctionId;  // Can be auction room ID or classified item ID
  final bool isClassified;
  final bool isEmdRequired;
  final double emdAmount;

  const EnquiryDialog({
    super.key, 
    required this.auctionTitle,
    this.auctionId,
    this.isClassified = false,
    this.isEmdRequired = false,
    this.emdAmount = 0.0,
  });

  static void show(
    BuildContext context, 
    String auctionTitle, {
    String? auctionId, 
    bool isClassified = false,
    bool isEmdRequired = false,
    double emdAmount = 0.0,
  }) {
    showDialog(
      context: context,
      builder: (context) => EnquiryDialog(
        auctionTitle: auctionTitle,
        auctionId: auctionId,
        isClassified: isClassified,
        isEmdRequired: isEmdRequired,
        emdAmount: emdAmount,
      ),
    );
  }

  @override
  State<EnquiryDialog> createState() => _EnquiryDialogState();
}

class _EnquiryDialogState extends State<EnquiryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  final _ddNumberController = TextEditingController();
  final _ddBankController = TextEditingController();
  final _ddDateController = TextEditingController();
  final _ddAmountController = TextEditingController();

  bool _isSending = false;
  bool _isLoggedIn = false;
  bool _isKycVerified = true;
  String _loggedInName = '';
  String _loggedInEmail = '';
  String _loggedInPhone = '';
  String _requestType = 'bidding'; // 'bidding' or 'query'

  String? _ddFileName;
  String? _ddFileObjectKey;
  bool _isUploadingDD = false;
  String? _ddUploadError;

  @override
  void initState() {
    super.initState();
    _messageController.text = "Yes, I am interested in this item. Kindly contact me through email or mobile.\n\nThanks";
    if (widget.isClassified) {
      _requestType = 'query';
    }
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService.getAccessToken();
    if (token != null) {
      final profile = await ApiService.getProfile();
      if (profile['success'] == true && mounted) {
        setState(() {
          _isLoggedIn = true;
          _isKycVerified = profile['data']['kyc_verified'] == true;
          _loggedInName = profile['data']['full_name'] ?? '';
          _loggedInEmail = profile['data']['email'] ?? '';
          _loggedInPhone = profile['data']['phone'] ?? '';
          
          _nameController.text = _loggedInName;
          _emailController.text = _loggedInEmail;
          _mobileController.text = _loggedInPhone;

          if (widget.isClassified) {
            _requestType = 'query';
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isKycVerified = false;
          _requestType = 'query'; // Guests can only send queries
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _ddNumberController.dispose();
    _ddBankController.dispose();
    _ddDateController.dispose();
    _ddAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDDFile() async {
    if (widget.auctionId == null || widget.auctionId!.isEmpty) return;
    try {
      checkFilePickerInit();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null) {
        final file = result.files.single;
        if (file.size > 5 * 1024 * 1024) {
          setState(() => _ddUploadError = 'File size must be under 5MB');
          return;
        }
        setState(() {
          _isUploadingDD = true;
          _ddUploadError = null;
        });
        final bytes = await getPlatformFileBytes(file);
        final res = await ApiService.uploadDDDocument(widget.auctionId!, bytes, file.name);
        if (res['success'] == true && mounted) {
          setState(() {
            _ddFileName = file.name;
            _ddFileObjectKey = res['object_key'];
            _isUploadingDD = false;
          });
        } else if (mounted) {
          setState(() {
            _ddUploadError = 'Failed to upload DD file';
            _isUploadingDD = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ddUploadError = 'Error picking file: $e';
          _isUploadingDD = false;
        });
      }
    }
  }

  String _extractErrorMessage(dynamic error, {String fallback = 'Could not process your request. Please try again.'}) {
    if (error == null) return fallback;
    if (error is String) {
      final trimmed = error.trim();
      return trimmed.isNotEmpty ? trimmed : fallback;
    }
    if (error is Map) {
      if (error['error'] != null) {
        return _extractErrorMessage(error['error'], fallback: fallback);
      }
      if (error['message'] != null) {
        return _extractErrorMessage(error['message'], fallback: fallback);
      }
      if (error['detail'] != null) {
        return _extractErrorMessage(error['detail'], fallback: fallback);
      }
      if (error['non_field_errors'] != null) {
        return _extractErrorMessage(error['non_field_errors'], fallback: fallback);
      }
      final List<String> errorParts = [];
      error.forEach((key, val) {
        final extracted = _extractErrorMessage(val, fallback: '');
        if (extracted.isNotEmpty) {
          errorParts.add(key == 'error' || key == 'detail' || key == 'message' ? extracted : '$key: $extracted');
        }
      });
      if (errorParts.isNotEmpty) {
        return errorParts.join('\n');
      }
    }
    if (error is List) {
      final nonNullItems = error.where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      if (nonNullItems.isNotEmpty) {
        return nonNullItems.map((e) => _extractErrorMessage(e, fallback: '')).where((s) => s.isNotEmpty).join('\n');
      }
    }
    final s = error.toString().trim();
    return s.isNotEmpty ? s : fallback;
  }

  Future<void> _sendEnquiry() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSending = true);

      try {
        String name = _nameController.text;
        String email = _emailController.text;
        String phone = _mobileController.text;

        bool success = false;
        String successMessage = '';
        String errorMessage = '';

        if (_isLoggedIn && _requestType == 'bidding') {
          if (widget.auctionId == null || widget.auctionId!.isEmpty) {
            setState(() => _isSending = false);
            GeminiInfoDialog.show(context, 'Error', 'Auction ID is missing.');
            return;
          }
          final result = await ApiService.registerInterest(
            widget.auctionId!,
            message: _messageController.text,
            contactPreference: 'either',
            ddNumber: _ddNumberController.text.trim(),
            ddBank: _ddBankController.text.trim(),
            ddDate: _ddDateController.text.trim(),
            ddAmount: double.tryParse(_ddAmountController.text.trim()),
            ddFile: _ddFileObjectKey,
          );
          success = result['success'] == true;
          successMessage = 'Your request to participate in bidding has been submitted for approval!';
          if (!success) {
            errorMessage = _extractErrorMessage(result['error']);
          }
        } else {
          // General Query (Guest or Logged-In)
          final result = await ApiService.submitEnquiry(
            name: name,
            email: email,
            phone: phone,
            message: _messageController.text,
            auctionId: widget.auctionId,
          );
          success = result['success'] == true;
          successMessage = 'Thank you for your interest! Your query has been submitted successfully.';
          if (!success) {
            errorMessage = _extractErrorMessage(result['error']);
          }
        }

        if (!mounted) return;
        setState(() => _isSending = false);

        if (success) {
          Navigator.pop(context);
          GeminiInfoDialog.show(
            context,
            _requestType == 'bidding' ? 'Bidding Request Sent' : 'Enquiry Submitted',
            successMessage,
          );
        } else {
          GeminiInfoDialog.show(
            context,
            'Submission Failed',
            errorMessage.isNotEmpty
                ? errorMessage
                : 'Could not process your request. Please try again.',
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSending = false);
        GeminiInfoDialog.show(
          context,
          'Network Error',
          'Failed to connect to the server. Please ensure you have an internet connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                color: Color(0xFF00AEEF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoggedIn && _requestType == 'bidding' ? 'Bidding Request' : 'Enquiry Form',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.rectangle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.auctionTitle,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      if (_isLoggedIn && !widget.isClassified) ...[
                        // Choice Selector for Logged-In Users
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _requestType = 'bidding'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _requestType == 'bidding' ? const Color(0xFF00AEEF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Bidding Request',
                                      style: TextStyle(
                                        color: _requestType == 'bidding' ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _requestType = 'query'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _requestType == 'query' ? const Color(0xFF00AEEF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'General Query',
                                      style: TextStyle(
                                        color: _requestType == 'query' ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Logged-In User Profile Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_circle, color: Color(0xFF00AEEF)),
                              const SizedBox(width: 10),
                              Text(
                                'Logged in as: $_loggedInName ($_loggedInEmail)',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoggedIn && _requestType == 'bidding' && !_isKycVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'KYC Verification Pending: Your account is not yet verified. Please ensure your KYC documents are approved before submitting bidding participation requests.',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_requestType == 'bidding') ...[
                          if (widget.isEmdRequired) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'EMD Demand Draft (DD) Details',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                                      ),
                                      if (widget.emdAmount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Required: ${formatCurrency(widget.emdAmount)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('DD Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _ddNumberController,
                                              enabled: !_isSending,
                                              decoration: _inputDecoration('e.g. 654321'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Issuing Bank Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _ddBankController,
                                              enabled: !_isSending,
                                              decoration: _inputDecoration('e.g. State Bank of India'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('DD Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _ddAmountController,
                                              enabled: !_isSending,
                                              keyboardType: TextInputType.number,
                                              decoration: _inputDecoration('e.g. 50000'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('DD Issue Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _ddDateController,
                                              enabled: !_isSending,
                                              decoration: _inputDecoration('YYYY-MM-DD'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: (_isSending || _isUploadingDD) ? null : _pickDDFile,
                                        icon: _isUploadingDD
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.upload_file, size: 18),
                                        label: Text(_isUploadingDD ? 'Uploading...' : 'Select DD Scanned Copy'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A237E),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (_ddFileName != null)
                                        Expanded(
                                          child: Text(
                                            '✓ Attached: $_ddFileName',
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_ddUploadError != null) ...[
                                    const SizedBox(height: 6),
                                    Text(_ddUploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No EMD / Registration Fee is required for this auction. You can submit your interest directly.',
                                      style: TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ] else ...[
                        // Guest Form Fields
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Your Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    enabled: !_isSending,
                                    decoration: _inputDecoration('Enter your name'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Your Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _mobileController,
                                    enabled: !_isSending,
                                    decoration: _inputDecoration('Enter your mobile number'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Text('Your Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isSending,
                          decoration: _inputDecoration('Enter your email'),
                          validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
                        ),
                        const SizedBox(height: 15),
                      ],
                      const Text('Your Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _messageController,
                        enabled: !_isSending,
                        maxLines: 4,
                        decoration: _inputDecoration(''),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF0288D1)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _requestType == 'bidding'
                                    ? 'Submitting this will notify the administrator to review and approve your participation.'
                                    : 'Our team will review your enquiry and contact you within 24 hours.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSending ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendEnquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00AEEF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    ),
                    child: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_requestType == 'bidding' ? 'Submit Bidding Request' : 'Send Query'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
