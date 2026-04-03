import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../Home/Screen/HomeScreenPage.dart';
import '../../Startup/MainControllere.dart';
import '../../ReUsable/registration_progress.dart';
import '../../ReUsable/enhanced_form_fields.dart';
import '../../constant/app_colors.dart';
import '../../service/updatepage.dart';

class IDVerificationScreen extends StatefulWidget {
  const IDVerificationScreen({super.key});

  @override
  State<IDVerificationScreen> createState() => _IDVerificationScreenState();
}

class _IDVerificationScreenState extends State<IDVerificationScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  String? _selectedDocumentType;
  final TextEditingController _documentNumberController = TextEditingController();
  XFile? _selectedImage;

  // Document status variables
  String _documentStatus = 'not_uploaded'; // 'not_uploaded', 'pending', 'approved', 'rejected'
  String _rejectReason = '';
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _isUploading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _documentTypes = [
    'Passport',
    'Driver\'s License',
    'National ID Card',
    'State ID',
    'PAN Card',
    'Aadhaar Card'
  ];

  @override
  void initState() {
    super.initState();
    _checkDocumentStatus();
    fetchMaritalStatus();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  String? mName;

  Future<void> fetchMaritalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) {
      _handleNoUserData();
      return;
    }

    final userData = jsonDecode(userDataString);
    final userId = int.tryParse(userData["id"].toString());

    if (userId == null) {
      _handleNoUserId();
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(
          "https://digitallami.com/api19/get_marital_status.php?userid=$userId",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true) {
          mName = data['data']['maritalStatusName'];
        } else {
          mName = null;
          debugPrint(data['message']);
        }
      } else {
        debugPrint("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("API error: $e");
    }
  }

  // Function to check document status
  Future<void> _checkDocumentStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) {
        _handleNoUserData();
        return;
      }

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString());

      if (userId == null) {
        _handleNoUserId();
        return;
      }

      print("Checking document status for user ID: $userId");

      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/check_document_status.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      print("Status check response: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            _documentStatus = result['status'] ?? 'not_uploaded';
            _rejectReason = result['reject_reason'] ?? '';
          });
          print("Document status: $_documentStatus");
          print("Reject reason: $_rejectReason");
        } else {
          print("API returned success: false");
          print("Message: ${result['message']}");
        }
      } else {
        print("HTTP error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error checking document status: $e");
      // Show error snackbar
      _showError("Failed to check document status: $e");
    } finally {
      setState(() {
        _isLoading = false;
        _isCheckingStatus = false;
      });
    }
  }

  void _handleNoUserData() {
    print("No user data found in SharedPreferences");
    setState(() {
      _isLoading = false;
      _isCheckingStatus = false;
    });
    _showError("User data not found. Please login again.");
  }

  void _handleNoUserId() {
    print("User ID is null");
    setState(() {
      _isLoading = false;
      _isCheckingStatus = false;
    });
  }

  // Function to refresh status
  Future<void> _refreshStatus() async {
    await _checkDocumentStatus();
  }

  // Upload document function
  Future<void> _uploadDocument() async {
    // If document was rejected, show rejection reason first
    if (_documentStatus == 'rejected' && _rejectReason.isNotEmpty) {
      _showRejectionDialog();
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    try {
      final uri = Uri.parse("https://digitallami.com/Api2/upload_document.php");

      var request = http.MultipartRequest("POST", uri);

      request.fields['userid'] = userId.toString();
      request.fields['documenttype'] = _selectedDocumentType!;
      request.fields['documentidnumber'] = _documentNumberController.text;

      // Add Image
      var imageFile = await http.MultipartFile.fromPath(
        'photo',
        _selectedImage!.path,
      );
      request.files.add(imageFile);

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print("Upload response: $responseBody");

      if (response.statusCode == 200) {
        // Update local status to pending
        setState(() {
          _documentStatus = 'pending';
          _rejectReason = '';
        });

        _showSuccess("Document uploaded successfully! Waiting for approval.");
      } else {
        _showError("Upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error uploading: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Document Rejected",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your previous document was rejected. Please review the reason below and upload again:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _rejectReason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear form for re-upload
              setState(() {
                _selectedDocumentType = null;
                _documentNumberController.clear();
                _selectedImage = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Upload New", style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    switch (_documentStatus) {
      case 'pending':
        return _buildPendingStatus();
      case 'approved':
        return _buildApprovedStatus();
      case 'rejected':
        return _buildRejectedStatus();
      default:
        return _buildUploadForm();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Checking verification status...",
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadForm() {
    return RegistrationStepContainer(
      onBack: () => Navigator.pop(context),
      onContinue: _canContinue() ? _validateAndSubmit : null,
      continueText: _isUploading ? 'Uploading...' : 'Submit Document',
      isLoading: _isUploading,
      canContinue: _canContinue() && !_isUploading,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            RegistrationStepHeader(
              title: 'ID Verification',
              subtitle: 'Upload your identification document for verification',
              currentStep: 11,
              totalSteps: 11,
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 32),

            // Skip Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isUploading ? null : _skipVerification,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Skip for now'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure & Private',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your documents are encrypted and stored securely',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Document Type Section
            const SectionHeader(
              title: 'Document Type',
              subtitle: 'Select your identification document',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),

            EnhancedDropdown<String>(
              label: 'Type of Document',
              value: _selectedDocumentType,
              items: _documentTypes,
              itemLabel: (item) => item,
              hint: 'Select document type',
              onChanged: (value) {
                setState(() {
                  _selectedDocumentType = value;
                });
              },
              isRequired: true,
              prefixIcon: Icons.description_outlined,
            ),
            const SizedBox(height: 32),

            // Document Number Section
            const SectionHeader(
              title: 'Document Details',
              subtitle: 'Enter your document identification number',
              icon: Icons.numbers_outlined,
            ),
            const SizedBox(height: 20),

            EnhancedTextField(
              label: 'Document ID Number',
              controller: _documentNumberController,
              hint: 'Enter ID number',
              prefixIcon: Icons.credit_card_outlined,
              keyboardType: TextInputType.text,
              onChanged: (value) => setState(() {}),
              validator: (value) => '',
            ),
            const SizedBox(height: 32),

            // Document Upload Section
            const SectionHeader(
              title: 'Upload Document',
              subtitle: 'Take a clear photo or choose from gallery',
              icon: Icons.cloud_upload_outlined,
            ),
            const SizedBox(height: 20),

            // Image Preview or Upload Button
            if (_selectedImage != null) ...[
              _buildImagePreview(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImageSourceSelector,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Change Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: const Text('Remove', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.error.withOpacity(0.5), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildUploadButton(),
            ],

            const SizedBox(height: 32),

            // Guidelines Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Photo Guidelines',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGuidelineItem(Icons.check_circle_outline, 'Ensure text is clearly visible'),
                  _buildGuidelineItem(Icons.check_circle_outline, 'Avoid glare and shadows'),
                  _buildGuidelineItem(Icons.check_circle_outline, 'Capture all four corners'),
                  _buildGuidelineItem(Icons.check_circle_outline, 'Use good lighting'),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return InkWell(
      onTap: _showImageSourceSelector,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Document Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to take photo or choose from gallery',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            FutureBuilder(
              future: _selectedImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  );
                }
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.white),
                    SizedBox(width: 6),
                    Text(
                      'Photo Selected',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _buildPendingStatus() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_bottom_rounded,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Under Review',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your document is being verified by our team',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.schedule, color: AppColors.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Estimated Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '24-48 hours',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goToHome,
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refreshStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedStatus() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withOpacity(0.2),
                    AppColors.success.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 80,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Verification Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your identity has been successfully verified',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your profile is now fully verified',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _completeRegistration,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedStatus() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.error.withOpacity(0.2),
                    AppColors.error.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Document Rejected',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please review the issue and upload again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (_rejectReason.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.error, size: 22),
                        SizedBox(width: 12),
                        Text(
                          'Reason for Rejection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _rejectReason,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _documentStatus = 'not_uploaded';
                    _selectedDocumentType = null;
                    _documentNumberController.clear();
                    _selectedImage = null;
                  });
                },
                icon: const Icon(Icons.upload),
                label: const Text('Upload New Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _skipVerification,
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip for Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.white),
                  ),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Use camera to take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library, color: AppColors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Select from your photos'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectFromGallery();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showError("Failed to take photo: $e");
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showError("Failed to select image: $e");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  bool _canContinue() {
    return _selectedDocumentType != null &&
        _documentNumberController.text.isNotEmpty &&
        _selectedImage != null;
  }

  void _validateAndSubmit() {
    if (_selectedDocumentType == null) {
      _showError("Please select document type");
      return;
    }

    if (_documentNumberController.text.isEmpty) {
      _showError("Please enter document number");
      return;
    }

    if (_selectedImage == null) {
      _showError("Please upload ID photo");
      return;
    }

    _uploadDocument();
  }

  void _skipVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Skip ID Verification?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            "You can verify your identity later from your profile settings.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToHome();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Skip", style: TextStyle(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainControllerScreen()),
      (route) => false,
    );
  }

  void _completeRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString());
      if (userId != null) {
        await UpdateService.updatePageNumber(
          userId: userId.toString(),
          pageNo: 10,
        );
      }
    }
    _goToHome();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
