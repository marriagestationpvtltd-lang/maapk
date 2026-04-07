import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../service/socket_service.dart';

class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  Timer? _timer;
  String? _currentUserId;

  final String _apiUrl =
      "https://digitallami.com/request/update_last_login.php";

  /// 🔥 Start tracking (call on app start / app resume)
  void start() {
    _updateNow(); // immediate call
    _restartTimer();
  }

  /// 🛑 Stop tracking (optional)
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Restart the periodic timer (also used after errors).
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateNow();
    });
  }

  /// 🔄 Update online status via Socket.IO and HTTP API
  Future<void> _updateNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();
      if (userId.isEmpty || userId == 'null') return;

      _currentUserId = userId;

      // Connect to Socket.IO if not already connected
      final socketService = SocketService();
      if (!socketService.isConnected) {
        socketService.connect(userId);
      }

      // Update HTTP API (best-effort, non-blocking for UI)
      unawaited(http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId}),
      ).catchError((e) {
        print("⚠️ Online API update failed (non-critical): $e");
      }));
    } catch (e) {
      print("❌ Online status error: $e");
      // Restart the timer in case of transient error
      _restartTimer();
    }
  }

  /// Set user offline (call when app goes to background)
  Future<void> setOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();
      if (userId.isEmpty || userId == 'null') return;

      // Disconnect socket so server registers the offline state
      SocketService().disconnect();

    } catch (e) {
      print("❌ Set offline error: $e");
    }
  }
}