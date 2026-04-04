import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Startup/SplashScreen.dart';
import '../constant/app_colors.dart';
import '../navigation/app_navigation.dart';
import '../service/connectivity_service.dart';

class GlobalConnectivityHandler extends StatefulWidget {
  final Widget child;

  const GlobalConnectivityHandler({
    super.key,
    required this.child,
  });

  @override
  State<GlobalConnectivityHandler> createState() =>
      _GlobalConnectivityHandlerState();
}

class _GlobalConnectivityHandlerState extends State<GlobalConnectivityHandler> {
  static const double _hiddenBannerOffsetMultiplier = -1.2;

  ConnectivityService? _connectivityService;
  Timer? _hideBannerTimer;
  bool _isBannerVisible = false;
  bool _isRetrying = false;
  bool _wasConnected = true;
  bool _isRefreshScheduled = false;
  String _bannerMessage = '';
  Color _bannerColor = AppColors.textSecondary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final connectivityService = context.read<ConnectivityService>();
    if (_connectivityService == connectivityService) {
      return;
    }

    _connectivityService?.removeListener(_onConnectivityChange);
    _connectivityService = connectivityService;
    _connectivityService?.addListener(_onConnectivityChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncBannerWithConnectivity();
      }
    });
  }

  @override
  void dispose() {
    _hideBannerTimer?.cancel();
    _connectivityService?.removeListener(_onConnectivityChange);
    super.dispose();
  }

  void _onConnectivityChange() {
    _syncBannerWithConnectivity();
  }

  void _syncBannerWithConnectivity() {
    if (!mounted) {
      return;
    }

    final connectivityService = _connectivityService;
    if (connectivityService == null) {
      return;
    }

    if (connectivityService.isConnected) {
      _showOnlineBannerIfNeeded();
      return;
    }

    _hideBannerTimer?.cancel();

    setState(() {
      _isRetrying = false;
      _isBannerVisible = true;
      _wasConnected = false;
      _bannerColor = AppColors.error;
      _bannerMessage = _buildOfflineMessage(connectivityService);
    });
  }

  String _buildOfflineMessage(ConnectivityService connectivityService) {
    if (connectivityService.isWifiConnected) {
      return 'Wi-Fi is connected, but internet access is unavailable.';
    }

    if (connectivityService.isMobileConnected) {
      return 'Mobile data is connected, but internet access is unavailable.';
    }

    return 'No internet connection.';
  }

  void _showOnlineBannerIfNeeded() {
    if (!mounted) {
      return;
    }

    final shouldRefresh = !_wasConnected;

    // Only show the "Back online" banner if we were previously offline.
    // On initial app launch _wasConnected is true so we skip the banner.
    if (!shouldRefresh) {
      setState(() {
        _wasConnected = true;
      });
      return;
    }

    _hideBannerTimer?.cancel();

    setState(() {
      _isRetrying = false;
      _isBannerVisible = true;
      _wasConnected = true;
      _bannerColor = Colors.black;
      _bannerMessage = 'Back online';
    });

    if (shouldRefresh) {
      _refreshCurrentRoute();
    }

    _hideBannerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBannerVisible = false;
      });
    });
  }

  Future<void> _handleRetry() async {
    final connectivityService = _connectivityService;
    if (_isRetrying || connectivityService == null) {
      return;
    }

    setState(() {
      _isRetrying = true;
    });

    final hasInternet = await connectivityService.checkConnectivity();
    if (!mounted) {
      return;
    }

    if (hasInternet) {
      _showOnlineBannerIfNeeded();
      return;
    }

    setState(() {
      _isRetrying = false;
      _bannerMessage = _buildOfflineMessage(connectivityService);
    });
  }

  void _refreshCurrentRoute() {
    if (_isRefreshScheduled) {
      return;
    }

    final navigator = navigatorKey.currentState;
    final route = appRouteTracker.currentRoute;

    if (navigator == null || route == null) {
      return;
    }

    _isRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRefreshScheduled = false;

      if (!mounted) {
        return;
      }

      if (route.settings.name != null && route.settings.name!.isNotEmpty) {
        navigator.pushReplacementNamed(
          route.settings.name!,
          arguments: route.settings.arguments,
        );
        return;
      }

      debugPrint(
        'Falling back to SplashScreen after reconnect because the current route '
        'could not be refreshed by name.',
      );
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
        ),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: !_isBannerVisible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: _isBannerVisible
                      ? Offset.zero
                      : const Offset(0, _hiddenBannerOffsetMultiplier),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    color: _bannerColor,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _bannerMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_bannerColor == AppColors.error)
                            TextButton(
                              onPressed: _isRetrying ? null : _handleRetry,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isRetrying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Retry',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
