// Professional Card Widgets
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/app_colors.dart';
import '../constant/app_dimensions.dart';
import '../constant/app_text_styles.dart';

// Base Card Widget
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: color ?? AppColors.white,
        elevation: elevation ?? AppDimensions.elevationSM,
        borderRadius: borderRadius ?? AppDimensions.borderRadiusMD,
        shadowColor: AppColors.shadowLight,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? AppDimensions.borderRadiusMD,
          child: Padding(
            padding: padding ?? AppDimensions.paddingMD,
            child: child,
          ),
        ),
      ),
    );
  }
}

// Profile Card Widget
class ProfileCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String? age;
  final String? location;
  final String? profession;
  final String? height;
  final bool? isPremium;
  final bool? isVerified;
  final bool? isOnline;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onMessage;

  const ProfileCard({
    super.key,
    required this.imageUrl,
    required this.name,
    this.age,
    this.location,
    this.profession,
    this.height,
    this.isPremium,
    this.isVerified,
    this.isOnline,
    this.onTap,
    this.onLike,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMD),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: AppColors.borderLight,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: AppColors.borderLight,
                    child: const Icon(
                      Icons.person,
                      size: 64,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
              // Badges
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    if (isPremium == true) ...[
                      _Badge(
                        icon: Icons.workspace_premium,
                        color: AppColors.premium,
                        label: 'Premium',
                      ),
                      AppSpacing.horizontalXS,
                    ],
                    if (isVerified == true)
                      _Badge(
                        icon: Icons.verified,
                        color: AppColors.verified,
                        label: 'Verified',
                      ),
                  ],
                ),
              ),
              // Online Status
              if (isOnline == true)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Details Section
          Padding(
            padding: AppDimensions.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Age
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        age != null ? '$name, $age' : name,
                        style: AppTextStyles.heading4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (profession != null) ...[
                  AppSpacing.verticalXS,
                  Row(
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: AppDimensions.iconSizeXS,
                        color: AppColors.textSecondary,
                      ),
                      AppSpacing.horizontalXS,
                      Expanded(
                        child: Text(
                          profession!,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (location != null) ...[
                  AppSpacing.verticalXS,
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: AppDimensions.iconSizeXS,
                        color: AppColors.textSecondary,
                      ),
                      AppSpacing.horizontalXS,
                      Expanded(
                        child: Text(
                          location!,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (height != null) ...[
                  AppSpacing.verticalXS,
                  Row(
                    children: [
                      const Icon(
                        Icons.height,
                        size: AppDimensions.iconSizeXS,
                        color: AppColors.textSecondary,
                      ),
                      AppSpacing.horizontalXS,
                      Text(
                        height!,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
                // Action Buttons
                if (onLike != null || onMessage != null) ...[
                  AppSpacing.verticalMD,
                  Row(
                    children: [
                      if (onLike != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onLike,
                            icon: const Icon(Icons.favorite_border, size: AppDimensions.iconSizeSM),
                            label: const Text('Like'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.spacingSM,
                              ),
                            ),
                          ),
                        ),
                      if (onLike != null && onMessage != null)
                        AppSpacing.horizontalSM,
                      if (onMessage != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onMessage,
                            icon: const Icon(Icons.message, size: AppDimensions.iconSizeSM),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.spacingSM,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Badge Widget
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Badge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSM,
        vertical: AppDimensions.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppDimensions.borderRadiusMD,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimensions.iconSizeXS, color: AppColors.white),
          AppSpacing.horizontalXS,
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Info Card Widget
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingSM),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: AppDimensions.borderRadiusMD,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: AppDimensions.iconSizeMD,
            ),
          ),
          AppSpacing.horizontalMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption,
                ),
                AppSpacing.verticalXS,
                Text(
                  value,
                  style: AppTextStyles.labelLarge,
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
            ),
        ],
      ),
    );
  }
}

// Stat Card Widget
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeLG,
            color: color ?? AppColors.primary,
          ),
          AppSpacing.verticalSM,
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
          ),
          AppSpacing.verticalXS,
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
