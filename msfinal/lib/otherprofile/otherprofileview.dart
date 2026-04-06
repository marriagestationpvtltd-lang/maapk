import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ms2026/otherprofile/profileheader.dart';
import 'package:ms2026/otherprofile/profiletabs.dart';
import 'package:ms2026/otherprofile/requestdiag.dart';
import 'package:ms2026/otherprofile/service_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import '../Notification/notification_inbox_service.dart';
import '../pushnotification/pushservice.dart';
import '../utils/privacy_utils.dart';
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

  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription<DocumentSnapshot>? _onlineStatusSub;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkDocumentStatus();
    _startOnlineStatusListener();
  }

  @override
  void dispose() {
    _onlineStatusSub?.cancel();
    super.dispose();
  }

  void _startOnlineStatusListener() {
    _onlineStatusSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId.toString())
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      bool online = false;
      DateTime? lastSeen;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool isOnline = data['isOnline'] == true;
        final Timestamp? ts = data['lastSeen'] as Timestamp?;
        lastSeen = ts?.toDate();
        final bool recentlySeen = lastSeen != null &&
            DateTime.now().difference(lastSeen).inMinutes < 5;
        online = isOnline || recentlySeen;
      }
      if (_isOtherUserOnline != online || _otherUserLastSeen != lastSeen) {
        setState(() {
          _isOtherUserOnline = online;
          _otherUserLastSeen = lastSeen;
        });
      }
    });
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

        _updatePhotoPrivacyStatus();
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

  /// Calculate photo privacy status from profile data
  /// Uses consistent logic: privacy == 'free' OR photo_request == 'accepted'
  void _updatePhotoPrivacyStatus() {
    if (_profileData == null) return;

    final privacy = _profileData!.personalDetail['privacy']?.toString().toLowerCase();
    final photoRequest = _profileData!.personalDetail['photo_request']?.toString().toLowerCase();

    // Use PrivacyUtils for consistent logic across the app
    final shouldShowClear = PrivacyUtils.shouldShowClearImage(
      privacy: privacy,
      photoRequest: photoRequest,
    );

    // Check if user has already requested photo access
    final hasRequested = photoRequest != null &&
                        photoRequest.isNotEmpty &&
                        photoRequest != 'null' &&
                        photoRequest != 'not_sent';

    setState(() {
      _showBlurredImage = !shouldShowClear;
      _hasRequestedPhoto = hasRequested;
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
        ),
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
    // Create a header instance to access the privacy banner
    final profileHeader = ProfileHeader(
      personalDetail: _profileData!.personalDetail,
      hasRequestedPhoto: _hasRequestedPhoto,
      onRequestPhotoAccess: _requestPhotoAccess,
      id: widget.userId.toString(),
      isOnline: _isOtherUserOnline,
      lastSeen: _otherUserLastSeen,
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          profileHeader,

          // Add privacy notice banner below the profile header
          profileHeader.buildPrivacyNoticeBanner(),

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
