import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _hasInternet = true;
  bool _isChecking = false;

  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  bool get hasInternet => _hasInternet;
  bool get isWifiConnected => _connectionStatus.contains(ConnectivityResult.wifi);
  bool get isMobileConnected => _connectionStatus.contains(ConnectivityResult.mobile);
  bool get isConnected => _hasInternet && _connectionStatus.isNotEmpty &&
      !_connectionStatus.contains(ConnectivityResult.none);

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Get initial status
      _connectionStatus = await _connectivity.checkConnectivity();
      await _checkActualInternetConnection();

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> result) async {
          _connectionStatus = result;
          await _checkActualInternetConnection();
          notifyListeners();

          if (kDebugMode) {
            print('📡 Connectivity changed: $_connectionStatus, Internet: $_hasInternet');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connectivity service initialization error: $e');
      }
      _hasInternet = false;
      notifyListeners();
    }
  }

  /// Check actual internet connection by trying to reach a reliable server
  Future<bool> _checkActualInternetConnection() async {
    if (_isChecking) return _hasInternet;

    _isChecking = true;
    try {
      // Try multiple reliable servers
      final results = await Future.wait([
        _checkHost('google.com'),
        _checkHost('cloudflare.com'),
      ]);

      _hasInternet = results.any((result) => result);
    } catch (e) {
      _hasInternet = false;
      if (kDebugMode) {
        print('❌ Internet check error: $e');
      }
    } finally {
      _isChecking = false;
    }

    notifyListeners();
    return _hasInternet;
  }

  /// Check if a specific host is reachable
  Future<bool> _checkHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Manual check for internet connectivity (use before important API calls)
  Future<bool> checkConnectivity() async {
    _connectionStatus = await _connectivity.checkConnectivity();
    return await _checkActualInternetConnection();
  }

  /// Get connection type as string (for display)
  String getConnectionType() {
    if (!_hasInternet) return 'No Internet';
    if (_connectionStatus.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (_connectionStatus.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (_connectionStatus.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (_connectionStatus.contains(ConnectivityResult.vpn)) return 'VPN';
    return 'Unknown';
  }

  /// Dispose subscription when not needed
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
