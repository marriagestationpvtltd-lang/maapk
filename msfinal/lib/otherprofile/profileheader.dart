import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'full_screen_image.dart';
import '../utils/time_utils.dart';

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> personalDetail;
  final bool hasRequestedPhoto;
  final Function onRequestPhotoAccess;
  final String id;
  final bool isOnline;
  final DateTime? lastSeen;

  const ProfileHeader({
    Key? key,
    required this.personalDetail,
    required this.hasRequestedPhoto,
    required this.onRequestPhotoAccess,
    required this.id,
    this.isOnline = false,
    this.lastSeen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Full-width profile image section
          _buildFullWidthProfileImage(context, screenWidth),

          // Profile info section
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.red.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              children: [
                // Name and verification
                _buildNameAndVerification(),
                const SizedBox(height: 6),

                // Online status
                _buildOnlineStatus(),
                const SizedBox(height: 8),

                // Member ID and location row
                _buildIdAndLocationRow(),
                const SizedBox(height: 20),

                // Info chips
                _buildInfoChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthProfileImage(BuildContext context, double screenWidth) {
    final imageUrl = personalDetail['profile_picture'] ?? '';
    final imageHeight = screenWidth * 0.7;

    // Get values from API
    final privacy = personalDetail['privacy']?.toString().toLowerCase();
    final photoRequest = personalDetail['photo_request']?.toString().toLowerCase();

    final bool isFreePrivacy = privacy == 'free';
    final bool isPhotoAccepted = photoRequest == 'accepted';
    final bool isPhotoPending = photoRequest == 'pending';
    final bool isPhotoRejected = photoRequest == 'rejected';

    // Check if photo_request has been sent (not null and not empty)
    final hasPhotoRequest = photoRequest != null && photoRequest.isNotEmpty && photoRequest != 'null';

    // ✅ FINAL UNBLUR CONDITION: privacy == free OR photo_request == accepted
    final bool showClearImage = isFreePrivacy || isPhotoAccepted;

    if (showClearImage) {
      return SizedBox(
        height: imageHeight,
        width: screenWidth,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (imageUrl.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
                    ),
                  );
                }
              },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: screenWidth,
                height: imageHeight,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    strokeWidth: 3,
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            // Tap hint overlay
            Positioned(
              bottom: 88,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Tap to expand',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.red.shade50.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ❌ BLURRED IMAGE (privacy != free AND photo not accepted)
    return Column(
      children: [
        SizedBox(
          height: imageHeight - 80,
          width: screenWidth,
          child: Stack(
            children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: screenWidth,
                  height: imageHeight - 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      strokeWidth: 3,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Container(color: Colors.black.withOpacity(0.3)),
            ],
          ),
        ),
        Container(
          width: screenWidth,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
          ),
          child: _buildPhotoAccessOverlay(),
        ),
      ],
    );
  }

  Widget _buildPhotoAccessOverlay() {
    // Get values from API
    final privacy = personalDetail['privacy']?.toString().toLowerCase();
    final photoRequest = personalDetail['photo_request']?.toString().toLowerCase();

    final isFreePrivacy = privacy == 'free';
    final isPhotoAccepted = photoRequest == 'accepted';
    final isPhotoPending = photoRequest == 'pending';
    final isPhotoRejected = photoRequest == 'rejected';

    // Check if photo_request has been sent
    final hasPhotoRequest = photoRequest != null &&
        photoRequest.isNotEmpty &&
        photoRequest != 'null';

    // Don't show overlay if privacy is free or photo is accepted
    if (isFreePrivacy || isPhotoAccepted) {
      return const SizedBox.shrink();
    }

    // Show request option only when photo_request is not sent
    if (!hasPhotoRequest) {
      return _buildRequestPhotoAccessUI();
    }

    // Otherwise show status from photo_request
    if (isPhotoPending) {
      return _buildPendingRequestUI();
    } else if (isPhotoRejected) {
      return _buildRejectedRequestUI();
    }

    // Fallback - should not reach here
    return _buildRequestPhotoAccessUI();
  }

  /// Build a privacy notice banner that appears below the profile header
  Widget buildPrivacyNoticeBanner() {
    // Get values from API
    final privacy = personalDetail['privacy']?.toString().toLowerCase();
    final photoRequest = personalDetail['photo_request']?.toString().toLowerCase();

    final isFreePrivacy = privacy == 'free';
    final isPhotoAccepted = photoRequest == 'accepted';
    final isPhotoPending = photoRequest == 'pending';
    final isPhotoRejected = photoRequest == 'rejected';

    // Check if photo_request has been sent
    final hasPhotoRequest = photoRequest != null &&
        photoRequest.isNotEmpty &&
        photoRequest != 'null';

    // Don't show banner if privacy is free or photo is accepted
    if (isFreePrivacy || isPhotoAccepted) {
      return const SizedBox.shrink();
    }

    // Build appropriate banner based on status
    if (isPhotoPending) {
      return _buildInfoBanner(
        icon: Icons.hourglass_bottom,
        color: Colors.orange,
        titleNepali: 'तपाईंको अनुरोध पेन्डिङ छ',
        titleEnglish: 'Photo Request Pending',
        messageNepali: 'यो युजरले तपाईंको फोटो हेर्ने अनुरोध स्वीकार गर्न बाँकी छ।',
        messageEnglish: 'This user has not yet responded to your photo access request.',
      );
    } else if (isPhotoRejected) {
      return _buildInfoBanner(
        icon: Icons.cancel,
        color: Colors.grey.shade600,
        titleNepali: 'तपाईंको अनुरोध अस्वीकार गरिएको छ',
        titleEnglish: 'Photo Request Rejected',
        messageNepali: 'यो युजरले तपाईंको फोटो हेर्ने अनुरोध अस्वीकार गरेको छ।',
        messageEnglish: 'This user has rejected your photo access request.',
      );
    } else {
      // No request sent yet
      return _buildInfoBanner(
        icon: Icons.lock,
        color: Colors.red.shade600,
        titleNepali: 'यो युजरले फोटो लक गरेको छ',
        titleEnglish: 'Photo is Locked',
        messageNepali: 'यो युजरको फोटो हेर्नको लागि तपाईंले रिक्वेस्ट पठाउनुपर्छ।',
        messageEnglish: 'You need to send a request to view this user\'s photo.',
      );
    }
  }

  /// Helper method to build info banner
  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String titleNepali,
    required String titleEnglish,
    required String messageNepali,
    required String messageEnglish,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleNepali,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  titleEnglish,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  messageNepali,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  messageEnglish,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPhotoAccessUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade600.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Photo Protected',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Request access to view full photo',
          style: TextStyle(
            fontSize: 14,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              onRequestPhotoAccess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shadowColor: Colors.black.withOpacity(0.3),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_red_eye_outlined, size: 20),
                SizedBox(width: 10),
                Text(
                  'Request Photo Access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.shade500.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.access_time,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Access Requested',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your photo request is pending approval',
          style: TextStyle(
            fontSize: 14,
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.orange.shade300,
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_bottom, color: Colors.orange, size: 20),
              SizedBox(width: 10),
              Text(
                'Awaiting Response',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedRequestUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade600.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.block,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Access Denied',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your photo request was rejected',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 10),
              Text(
                'Request Rejected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    if (isOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Online',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    if (lastSeen != null) {
      return Text(
        formatLastSeen(lastSeen!),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNameAndVerification() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'MS:${id} ${personalDetail['lastName'] ?? ''}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            letterSpacing: 0.5,
          ),
        ),
        if (personalDetail['isVerified'] == 1)
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.white,
              size: 22,
            ),
          ),
      ],
    );
  }

  Widget _buildIdAndLocationRow() {
    final city = personalDetail['city'] ?? '';
    final country = personalDetail['country'] ?? '';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.badge_outlined,
              color: Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'ID: ${personalDetail['memberid'] ?? 'N/A'}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (city.isNotEmpty || country.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.red.shade400,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '$city${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}$country',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChips() {
    final age = _calculateAge(personalDetail['birthDate']);
    final height = personalDetail['height_name'] ?? 'N/A';
    final designation = personalDetail['designation'] ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem(Icons.cake_outlined, age, 'Age'),
          _buildDivider(),
          _buildInfoItem(Icons.height_outlined, height, 'Height'),
          _buildDivider(),
          _buildInfoItem(Icons.work_outline, designation, 'Profession'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade100, width: 2),
            ),
            child: Icon(
              icon,
              color: Colors.red.shade400,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade300,
    );
  }

  String _calculateAge(String? birthDate) {
    if (birthDate == null) return 'N/A';
    try {
      final dob = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return '$age yrs';
    } catch (e) {
      return 'N/A';
    }
  }
}