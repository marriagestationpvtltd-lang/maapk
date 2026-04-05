// matched_profile_card.dart
// Reusable Flutter widgets for the horizontal matched-profiles UI.
// Usage:
// import 'matched_profile_card.dart';
//
// MatchedProfilesList(
//   profiles: yourListOfMaps,
//   onSendRequest: (profile) { /* handle send request */ },
// )

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ms2026/constant/app_colors.dart';
import 'package:ms2026/constant/app_dimensions.dart';
import 'package:ms2026/constant/app_text_styles.dart';
import 'package:ms2026/utils/privacy_utils.dart';

typedef SendRequestCallback = void Function(Map<String, dynamic> profile);

class MatchedProfilesList extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;
  final SendRequestCallback? onSendRequest;
  final EdgeInsetsGeometry padding;
  final double cardWidth;

  const MatchedProfilesList({
    Key? key,
    required this.profiles,
    this.onSendRequest,
    this.padding = const EdgeInsets.only(left: AppDimensions.spacingMD),
    this.cardWidth = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 276,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        padding: padding,
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return Container(
            margin: const EdgeInsets.only(right: AppDimensions.spacingMD),
            width: cardWidth,
            child: MatchedProfileCard(
              profile: profile,
              onSendRequest: () => onSendRequest?.call(profile),
              // forward status if present on profile map (keys: request_status)
              currentStatus: profile['request_status']?.toString(),
            ),
          );
        },
      ),
    );
  }
}

class MatchedProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback? onSendRequest;
  final String? currentStatus; // null | 'loading' | 'pending' | 'sent' | 'error'

  const MatchedProfileCard({
    Key? key,
    required this.profile,
    this.onSendRequest,
    this.currentStatus,
  }) : super(key: key);

  String _getString(dynamic value) => (value ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final name = _getString(profile['firstName']).isEmpty ? (_getString(profile['name']).isEmpty ? 'Name' : profile['name']) : profile['firstName'];
    final age = _getString(profile['age']);
    final height = _getString(profile['height_name'] ?? profile['height']);
    final profession = _getString(profile['designation'] ?? profile['profession']);
    final location = _getString((profile['city'] != null ? profile['city'] + (profile['country'] != null ? ', ' + profile['country'] : '') : profile['location']) ?? '');
    final imageUrl = _getString(profile['profile_picture'] ?? profile['image']);

    // Privacy fields
    final privacy = _getString(profile['privacy']);
    final photoRequest = _getString(profile['photo_request']);
    final shouldShowClear = PrivacyUtils.shouldShowClearImage(
      privacy: privacy,
      photoRequest: photoRequest,
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXS),
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image + name overlay with privacy enforcement
          Stack(
            children: [
              SizedBox(
                height: 140,
                child: imageUrl.isNotEmpty
                    ? shouldShowClear
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (c, e, s) => _placeholder(),
                        )
                      : ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: PrivacyUtils.kStandardBlurSigmaX,
                            sigmaY: PrivacyUtils.kStandardBlurSigmaY,
                          ),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (c, e, s) => _placeholder(),
                          ),
                        )
                    : _placeholder(),
              ),
              // Lock overlay for blurred images
              if (!shouldShowClear)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: AppColors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PrivacyUtils.getPhotoRequestStatusLabel(photoRequest),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Name overlay - only show if image is clear
              if (shouldShowClear)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    color: Colors.black.withOpacity(0.55),
                    child: Text(
                      name,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),

          // Info section - show full details only if image is clear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSM, vertical: AppDimensions.spacingSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shouldShowClear) ...[
                  Text(
                    'Age ${age.isEmpty ? '-' : age} yrs, ${height.isEmpty ? '-' : height} cm',
                    style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.work_outline, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: AppDimensions.spacingXS),
                      Expanded(
                        child: Text(
                          profession.isEmpty ? '-' : profession,
                          style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: AppDimensions.spacingXS),
                      Expanded(
                        child: Text(
                          location.isEmpty ? '-' : location,
                          style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spacingSM),
                ] else ...[
                  // When photo is blurred, show minimal info
                  const Text(
                    'Photo Protected - Send Request to View',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                ],

                // Send Request Button (now reacts to currentStatus)
                SizedBox(
                  height: AppDimensions.buttonHeightSM,
                  child: _buildStatusButton(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context) {
    final status = (currentStatus ?? '').toLowerCase();

    String label;
    bool enabled;

    switch (status) {
      case 'loading':
        label = 'Sending...';
        enabled = false;
        break;
      case 'pending':
        label = 'Pending';
        enabled = false;
        break;
      case 'sent':
        label = 'Sent';
        enabled = false;
        break;
      case 'error':
        label = 'Retry';
        enabled = true;
        break;
      default:
        label = 'Send Request';
        enabled = true;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          onTap: enabled ? onSendRequest : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (status == 'loading') ...[
                    SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(Icons.send, size: 13, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.spacingXS),
                  ],

                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.border,
      child: const Center(
        child: Icon(Icons.person, size: AppDimensions.iconSizeXXL, color: AppColors.textSecondary),
      ),
    );
  }
}
