import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  Timer? _timer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _apiUrl =
      "http://192.168.1.9/request/update_last_login.php";

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
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateNow();
    });
  }

  /// 🔄 Update lastLogin API and Firestore online status
  Future<void> _updateNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();
      if (userId.isEmpty || userId == 'null') return;

      // Update Firestore online status first (lower latency, drives UI)
      await _firestore.collection('users').doc(userId).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

  /// Set user offline in Firestore (call when app goes to background)
  Future<void> setOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();
      if (userId.isEmpty || userId == 'null') return;

      await _firestore.collection('users').doc(userId).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("❌ Set offline error: $e");
    }
  }
}