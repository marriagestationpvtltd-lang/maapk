import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:ms2026/otherprofile/profileheader.dart';
import 'package:ms2026/otherprofile/profiletabs.dart';
import 'package:ms2026/otherprofile/requestdiag.dart';
import 'package:ms2026/otherprofile/service_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../Notification/notification_inbox_service.dart';
import '../pushnotification/pushservice.dart';
import 'gallerysection.dart';
import 'loadingerror.dart';
import 'modelprofile.dart';



class UserProfilePage extends StatefulWidget {
    final dynamic userId;

 UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  int get _parsedUserId => int.parse(widget.userId.toString());

  ProfileData? _profileData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showBlurredImage = true;
  bool _hasRequestedPhoto = false;
  List<GalleryImage> _galleryImages = [];
  bool _showPopup = false;
  String _popupMessage = '';
  String _docStatus = 'not_uploaded';

  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkDocumentStatus();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');


      final userData = json.decode(userDataString!);
       final userid = int.tryParse(userData["id"].toString());




    try {
      final profileResponse = await _profileService.fetchProfileData(_parsedUserId, userid!);

      if (profileResponse['status'] == 'success') {
        setState(() {
          _profileData = ProfileData.fromJson(profileResponse['data']);
        });

        await _checkPhotoPrivacy();
        await _fetchGalleryImages();

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = profileResponse['message'] ?? 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPhotoPrivacy() async {
    final privacyData = await _profileService.checkPhotoPrivacy(_parsedUserId);
    setState(() {
      _showBlurredImage = privacyData['show_blur'] ?? true;
      _hasRequestedPhoto = privacyData['has_requested'] ?? false;
    });
  }


  Future<void> _fetchGalleryImages() async {
    final images = await _profileService.fetchGalleryImages(_parsedUserId);
    setState(() {
      _galleryImages = images;
    });
  }

  Future<void> _checkDocumentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = json.decode(userDataString);
      setState(() {
        _docStatus = userData['docstatus'] ?? 'not_uploaded';
      });
    }
  }

  void _showRequestSentPopup(String message) {
    setState(() {
      _popupMessage = message;
      _showPopup = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showPopup = false;
        });
      }
    });
  }

  void _showSendRequestDialog() {
    if (_profileData == null) return;

    showDialog(
      context: context,
      builder: (context) => RequestDialog(
        receiverName: '${_profileData!.personalDetail['lastName']}',
        onSendRequest: _sendRequest,
      ),
    );
  }

  Future<void> _sendRequest(String requestType) async {
    try {
      final senderId = await ProfileService.getCurrentUserId();
      if (senderId == null) {
        _showRequestSentPopup('Please login to send request');
        return;
      }

      final response = await _profileService.sendRequest(
        senderId: senderId,
        receiverId: _parsedUserId,
        requestType: requestType,
      );

      if (response['success'] == true) {
        bool success = await NotificationService.sendRequestNotification(
          recipientUserId:  widget.userId.toString(),       // ID of the user receiving the request
          senderName: "MS:${senderId}",       // Name of the sender
          senderId: senderId.toString(),              // ID of the sender
          requestType: requestType,
        );

        if(success) {
          print("Request notification sent!");
        } else {
          print("Failed to send notification.");
        }
        await NotificationInboxService.recordOutgoingRequest(
          recipientUserId: widget.userId.toString(),
          requestType: requestType,
          recipientName: '${_profileData?.personalDetail['lastName'] ?? ''}'.trim(),
        );
        _showRequestSentPopup(response['message'] ?? 'Request sent successfully!');

        if (requestType == 'Photo') {
          setState(() {
            _hasRequestedPhoto = true;
          });
        }
      } else {
        _showRequestSentPopup(response['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      _showRequestSentPopup('Error: $e');
    }
  }

  void _requestPhotoAccess() {

        _showSendRequestDialog();

  }



  Widget _buildPopupMessage() {
    return AnimatedOpacity(
      opacity: _showPopup ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _popupMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                setState(() {
                  _showPopup = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfileData,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const LoadingWidget()
          else if (_errorMessage.isNotEmpty)
            ErrorWidget(
              errorMessage: _errorMessage,
              onRetry: _loadProfileData,
            )
          else if (_profileData != null)
              _buildProfileContent()
            else
              const Center(child: Text('No profile data available')),

          if (_showPopup) _buildPopupMessage(),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileHeader(
            personalDetail: _profileData!.personalDetail,
            showBlurredImage: _showBlurredImage,
            hasRequestedPhoto: _hasRequestedPhoto,

            onRequestPhotoAccess: _requestPhotoAccess, id: widget.userId.toString(),
          ),

          GallerySection(
            galleryImages: _galleryImages,
            showBlurredImage: _showBlurredImage,
            hasRequestedPhoto: _hasRequestedPhoto,
            onRequestAccess: _requestPhotoAccess,
          ),

          ProfileTabs(
            personalDetail: _profileData!.personalDetail,
            familyDetail: _profileData!.familyDetail,
            lifestyle: _profileData!.lifestyle,
            partner: _profileData!.partner, id: widget.userId.toString(),
          ),
        ],
      ),
    );
  }
}
