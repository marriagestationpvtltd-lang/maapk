import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constant/app_colors.dart';
import '../constant/app_dimensions.dart';
import '../service/connectivity_service.dart';
import 'dart:io' show Platform;

class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Listen to connectivity changes
    _connectivityService.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (_connectivityService.isConnected && mounted) {
      // Auto-close when internet is back
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChange);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isChecking = true;
    });

    final hasInternet = await _connectivityService.checkConnectivity();

    setState(() {
      _isChecking = false;
    });

    if (hasInternet && mounted) {
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        _showNoConnectionSnackBar();
      }
    }
  }

  void _showNoConnectionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _connectivityService.isWifiConnected
              ? 'WiFi जडान भएको छ तर इन्टरनेट छैन'
              : _connectivityService.isMobileConnected
                  ? 'मोबाइल डाटा जडान भएको छ तर इन्टरनेट छैन'
                  : 'अझै पनि इन्टरनेट जडान छैन',
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openWifiSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('सेटिङ्ग खोल्न सकिएन'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openMobileDataSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('सेटिङ्ग खोल्न सकिएन'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWifiOff = !_connectivityService.isWifiConnected &&
        !_connectivityService.isMobileConnected;
    final bool isMobileDataOff = !_connectivityService.isMobileConnected &&
        !_connectivityService.isWifiConnected;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated No Internet Icon
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 100,
                            color: AppColors.error,
                          ),
                        ),
                      );
                    },
                  ),
                  AppSpacing.verticalXL,

                  // Title
                  const Text(
                    'इन्टरनेट जडान छैन',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.verticalMD,

                  // Description
                  Text(
                    isWifiOff && isMobileDataOff
                        ? 'तपाईंको इन्टरनेट जडान छैन। कृपया WiFi वा मोबाइल डाटा सक्रिय गर्नुहोस्।'
                        : _connectivityService.isWifiConnected
                            ? 'WiFi जडान भएको छ तर इन्टरनेट छैन। कृपया तपाईंको WiFi जडान जाँच गर्नुहोस्।'
                            : _connectivityService.isMobileConnected
                                ? 'मोबाइल डाटा जडान भएको छ तर इन्टरनेट छैन। कृपया तपाईंको मोबाइल डाटा जाँच गर्नुहोस्।'
                                : 'कृपया तपाईंको इन्टरनेट जडान जाँच गर्नुहोस् र पुन: प्रयास गर्नुहोस्।',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.verticalXL,

                  // Connection Status Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildConnectionRow(
                          'WiFi',
                          _connectivityService.isWifiConnected,
                          Icons.wifi_rounded,
                          _openWifiSettings,
                        ),
                        AppSpacing.verticalMD,
                        _buildConnectionRow(
                          'मोबाइल डाटा',
                          _connectivityService.isMobileConnected,
                          Icons.signal_cellular_alt_rounded,
                          _openMobileDataSettings,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.verticalXL,

                  // Retry Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _handleRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.white),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _isChecking ? 'जाँच गर्दै...' : 'पुन: प्रयास गर्नुहोस्',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.verticalMD,

                  // Settings Button
                  if (isWifiOff || isMobileDataOff)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openWifiSettings,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text(
                          'सेटिङ्ग खोल्नुहोस्',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildConnectionRow(
    String title,
    bool isConnected,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: isConnected ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isConnected ? AppColors.success : AppColors.error,
                size: 24,
              ),
            ),
            AppSpacing.horizontalMD,
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isConnected ? 'जडान भएको' : 'जडान छैन',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isConnected ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            if (!isConnected) ...[
              AppSpacing.horizontalSM,
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
