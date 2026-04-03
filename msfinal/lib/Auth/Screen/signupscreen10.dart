import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../Home/Screen/HomeScreenPage.dart';
import '../../Startup/MainControllere.dart';
import '../../service/updatepage.dart';

class IDVerificationScreen extends StatefulWidget {
  const IDVerificationScreen({super.key});

  @override
  State<IDVerificationScreen> createState() => _IDVerificationScreenState();
}

class _IDVerificationScreenState extends State<IDVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedDocumentType;
  final TextEditingController _documentNumberController = TextEditingController();
  XFile? _selectedImage;

  // Document status variables
  String _documentStatus = 'not_uploaded'; // 'not_uploaded', 'pending', 'approved', 'rejected'
  String _rejectReason = '';
  bool _isLoading = true;
  bool _isCheckingStatus = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to check document status: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("User data not found. Please login again."),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
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

  // Upload document function (keep your existing)
  Future<void> _uploadDocument() async {
    // If document was rejected, show rejection reason first
    if (_documentStatus == 'rejected' && _rejectReason.isNotEmpty) {
      _showRejectionDialog();
      return;
    }

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

        // Update page number

        _showSuccess("Document uploaded successfully! Waiting for approval.");
      } else {
        _showError("Upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error uploading: $e");
    }
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text(
              "Document Rejected",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your previous document was rejected. Please fix the issue below and upload again:",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _rejectReason,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Would you like to upload a new document?",
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
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
              backgroundColor: const Color(0xFFE64B37),
            ),
            child: const Text(
              "Upload New",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF48A54C)),
            SizedBox(width: 10),
            Text(
              "Success",
              style: TextStyle(
                color: Color(0xFF48A54C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Go to home screen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => MainControllerScreen()),
                    (route) => false,
              );
            },
            child: const Text(
              "Continue",
              style: TextStyle(color: Color(0xFF48A54C)),
            ),
          ),
        ],
      ),
    );
  }

  // Status-based UI builders
  Widget _buildStatusWidget() {
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

  Widget _buildPendingStatus() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade100,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Icon(
                Icons.hourglass_bottom,
                size: 60,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 20),
              const Text(
                "Document Under Review",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                "Your ID document has been submitted and is currently being reviewed by our team.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20),
              const Text(
                "We'll notify you once the verification is complete.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => MainControllerScreen()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home, color: Colors.white),
                  label: const Text(
                    "Go to Home",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton.icon(
                onPressed: _refreshStatus,
                icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                label: Text(
                  "Check Status",
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _skipVerification,
                child: const Text(
                  "Skip for Now",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovedStatus() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade100,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Icon(
                Icons.verified_user,
                size: 60,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 20),
              const Text(
                "Verification Approved!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                "Your ID document has been successfully verified and approved.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Your account is now fully verified",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Future.microtask(() async {
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
                      bool updated = await UpdateService.updatePageNumber(
                        userId: userId.toString(),
                        pageNo: 10,
                      );
                      print("Page update result: $updated");
                    });

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => MainControllerScreen()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text(
                    "Continue to Dashboard",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedStatus() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade100,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 20),
              const Text(
                "Document Rejected",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                "We couldn't verify your document. Please see the reason below:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20),

              if (_rejectReason.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Rejection Reason:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _rejectReason,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 25),
              const Text(
                "Please upload a new document with the required corrections.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red),
              ),
              const SizedBox(height: 30),

              // Re-upload button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Clear old data and show upload form
                    setState(() {
                      _documentStatus = 'not_uploaded';
                      _selectedDocumentType = null;
                      _documentNumberController.clear();
                      _selectedImage = null;
                    });
                  },
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text(
                    "Upload New Document",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE64B37),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Skip button
              TextButton.icon(
                onPressed: _skipVerification,
                icon: const Icon(Icons.skip_next, color: Colors.red),
                label: const Text(
                  "Skip Verification",
                  style: TextStyle(color: Colors.red),
                ),
              ),

              const SizedBox(height: 10),

              // Refresh status button
              TextButton.icon(
                onPressed: _refreshStatus,
                icon: Icon(Icons.refresh, color: Colors.red.shade600),
                label: Text(
                  "Refresh Status",
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE64B37),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFFE64B37),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFE64B37),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectFromGallery();
                },
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(
                  Icons.cancel,
                  color: Colors.grey,
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Upload a photo of your ID Proof',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Regulations require you to upload a citizenship id. Don\'t worry, your data will stay safe and private.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 25),
        _buildSectionTitle("Document Type*"),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedDocumentType,
          hint: "Select Document Type",
          items: _documentTypes,
          onChanged: (value) {
            setState(() {
              _selectedDocumentType = value;
            });
          },
        ),
        const SizedBox(height: 20),
        // Image Preview Section
        if (_selectedImage != null) ...[
          _buildImagePreviewSection(),
          const SizedBox(height: 16),
        ],
        if (_selectedImage == null) ...[
          _buildPrimaryButton(
            text: 'Upload ID Photo',
            icon: Icons.cloud_upload,
            onPressed: _showImageSourceSelector,
          ),
          const SizedBox(height: 16),
        ],

// Camera Button (for retake when image is already selected)
        if (_selectedImage != null) ...[
          _buildPrimaryButton(
            text: 'Retake Photo',
            icon: Icons.camera_alt,
            onPressed: _showImageSourceSelector,
          ),
          const SizedBox(height: 12),
        ],



        if (_selectedImage != null) ...[
          const SizedBox(height: 12),
          _buildOutlineButton(
            text: 'Choose different photo',
            onPressed: _selectFromGallery,
          ),
        ],
        const SizedBox(height: 20),


        // Document ID Number
        _buildSectionTitle("Document Id Number*"),
        const SizedBox(height: 8),
        _buildDocumentNumberField(),


        // Document Type



        // Divider
        const Divider(height: 1, color: Colors.grey),



        const SizedBox(height: 35),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: _buildButton(
                text: "Previous",
                isPrimary: false,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildButton(
                text: "Continue",
                isPrimary: true,
                onPressed: _canContinue() ? () {
                  _validateAndSubmit();
                } : null,
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Skip button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (_documentStatus == 'not_uploaded')
                        Container(
                          height: 35,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE64B37),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _skipVerification,
                              child: const Center(
                                child: Text(
                                  "Skip",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(left: 60),
                          child: const Text(
                            "ID Verification",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE64B37),
                            ),
                          ),
                        ),
                      ),
                      // Refresh button for status screens
                      if (_documentStatus != 'not_uploaded')
                        IconButton(
                          onPressed: _refreshStatus,
                          icon: Icon(
                            Icons.refresh,
                            color: Colors.blue.shade600,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Show loading or status content
                  if (_isLoading)
                    Container(
                      height: 300,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Color(0xFFE64B37)),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Checking document status...",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildStatusWidget(),
                ],
              ),
            ),

            // Progress bubble
            Positioned(
              right: 12,
              top: 8,
              child: _progressBubble(0.60, "100%"),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for image handling (keep your existing methods)
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _skipVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Skip ID Verification?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE64B37),
            ),
          ),
          content: const Text(
            "Are you sure you want to skip ID verification? This is required for account security.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MainControllerScreen()),
                );
              },
              child: const Text(
                "Skip",
                style: TextStyle(
                  color: Color(0xFFE64B37),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // UI Helper methods (keep your existing methods)
  Widget _buildImagePreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "ID Photo Preview",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF48A54C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Selected",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF48A54C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildImagePreview(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _showImageSourceSelector,
              child: Text(
                "Change photo",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _removeImage,
              child: Text(
                "Remove photo",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FutureBuilder(
          future: _selectedImage!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return Stack(
                children: [
                  Image.memory(
                    snapshot.data!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        _selectedDocumentType ?? 'Unknown Document',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                        onPressed: _removeImage,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF48A54C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "Uploaded",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFE64B37)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1.6,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDocumentNumberField() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1.6,
        ),
      ),
      child: TextFormField(
        controller: _documentNumberController,
        decoration: const InputDecoration(
          hintText: 'Your Document Number',
          border: InputBorder.none,
          hintStyle: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1.6,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF48A54C),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE64B37),
            Color(0xFFE62255),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
          colors: [
            Color(0xFFE64B37),
            Color(0xFFE62255),
          ],
        )
            : const LinearGradient(
          colors: [
            Color(0xFFEEA2A4),
            Color(0xFFF3C0C4),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBubble(double progress, String label) {
    final size = 42.0;
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: .2,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE64B37)),
              backgroundColor: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE64B37),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _documentNumberController.dispose();
    super.dispose();
  }
}