import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_navigation.dart';
import '../screens/no_internet_screen.dart';
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
  ConnectivityService? _connectivityService;
  Route<void>? _offlineRoute;
  bool _isOfflineRouteVisible = false;
  bool _isRecoveringConnection = false;
  bool _isRefreshScheduled = false;

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
        _onConnectivityChange();
      }
    });
  }

  @override
  void dispose() {
    _connectivityService?.removeListener(_onConnectivityChange);
    super.dispose();
  }

  void _onConnectivityChange() {
    unawaited(_handleConnectivityChange());
  }

  Future<void> _handleConnectivityChange() async {
    if (!mounted) {
      return;
    }

    final connectivityService = _connectivityService;
    final navigator = navigatorKey.currentState;

    if (connectivityService == null || navigator == null) {
      return;
    }

    if (connectivityService.isConnected) {
      if (_isOfflineRouteVisible) {
        await _recoverFromOffline();
      }
      return;
    }

    if (_isOfflineRouteVisible) {
      return;
    }

    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: noInternetRouteName),
      builder: (_) => NoInternetScreen(
        onRetry: _handleRetry,
      ),
    );

    _offlineRoute = route;
    _isOfflineRouteVisible = true;
    navigator.push(route).then((_) {
      if (_offlineRoute == route) {
        _offlineRoute = null;
      }
      _isOfflineRouteVisible = false;
    });
  }

  Future<void> _handleRetry() async {
    if (_isRecoveringConnection) {
      return;
    }

    final connectivityService = _connectivityService;
    final navigator = navigatorKey.currentState;

    if (connectivityService == null || navigator == null) {
      return;
    }

    final hasInternet = await connectivityService.checkConnectivity();
    if (!hasInternet) {
      return;
    }

    await _recoverFromOffline();
  }

  Future<void> _recoverFromOffline() async {
    if (_isRecoveringConnection) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _isRecoveringConnection = true;

    try {
      if (_isOfflineRouteVisible && _offlineRoute != null) {
        navigator.removeRoute(_offlineRoute!);
        _offlineRoute = null;
        _isOfflineRouteVisible = false;
      }

      _refreshCurrentRoute();
    } finally {
      _isRecoveringConnection = false;
    }
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

    if (route.settings.name != null && route.settings.name!.isNotEmpty) {
      _isRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isRefreshScheduled = false;
        if (!mounted) {
          return;
        }
        navigator.pushReplacementNamed(
          route.settings.name!,
          arguments: route.settings.arguments,
        );
      });
      return;
    }

    if (route is MaterialPageRoute<dynamic>) {
      _isRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isRefreshScheduled = false;
        if (!mounted) {
          return;
        }
        navigator.pushReplacement(
          MaterialPageRoute<dynamic>(
            builder: route.builder,
            settings: route.settings,
            fullscreenDialog: route.fullscreenDialog,
            maintainState: route.maintainState,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
