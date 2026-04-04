// Professional Loading and Error Widgets
import 'package:flutter/material.dart';
import '../constant/app_colors.dart';
import '../constant/app_dimensions.dart';
import '../constant/app_text_styles.dart';

// Loading Widget
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 40,
            height: size ?? 40,
            child: const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            AppSpacing.verticalMD,
            Text(
              message!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Circular Loading Indicator
class CircularLoading extends StatelessWidget {
  final Color? color;
  final double? size;

  const CircularLoading({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        color: color ?? AppColors.primary,
        strokeWidth: 2,
      ),
    );
  }
}

// Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimensions.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeXXL * 2,
              color: AppColors.textHint,
            ),
            AppSpacing.verticalLG,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading3,
            ),
            if (subtitle != null) ...[
              AppSpacing.verticalSM,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              AppSpacing.verticalLG,
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXL,
                    vertical: AppDimensions.spacingMD,
                  ),
                ),
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Error Widget
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? retryButtonText;

  const ErrorStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.errorMessage,
    this.onRetry,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimensions.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: AppDimensions.iconSizeXXL * 2,
              color: AppColors.error,
            ),
            AppSpacing.verticalLG,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading3,
            ),
            if (subtitle != null) ...[
              AppSpacing.verticalSM,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (errorMessage != null) ...[
              AppSpacing.verticalSM,
              Container(
                padding: AppDimensions.paddingMD,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: AppDimensions.borderRadiusMD,
                ),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              AppSpacing.verticalLG,
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXL,
                    vertical: AppDimensions.spacingMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Success Message Widget
class SuccessMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;

  const SuccessMessageWidget({
    super.key,
    required this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppDimensions.paddingMD,
      padding: AppDimensions.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: AppDimensions.borderRadiusMD,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.white,
            size: AppDimensions.iconSizeLG,
          ),
          AppSpacing.horizontalMD,
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.whiteBody.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClose != null) ...[
            AppSpacing.horizontalSM,
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.white),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

// Warning Message Widget
class WarningMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;

  const WarningMessageWidget({
    super.key,
    required this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppDimensions.paddingMD,
      padding: AppDimensions.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: AppDimensions.borderRadiusMD,
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_rounded,
            color: AppColors.white,
            size: AppDimensions.iconSizeLG,
          ),
          AppSpacing.horizontalMD,
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.whiteBody.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClose != null) ...[
            AppSpacing.horizontalSM,
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.white),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

// Shimmer Loading Effect (for skeleton screens)
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                AppColors.borderLight,
                AppColors.white,
                AppColors.borderLight,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
