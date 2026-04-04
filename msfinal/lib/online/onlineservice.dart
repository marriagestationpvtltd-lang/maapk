import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  Timer? _timer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _apiUrl =
      "https://digitallami.com/request/update_last_login.php";

  /// 🔥 Start tracking (call on app start)
  void start() {
    _updateNow(); // immediate call

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateNow();
    });
  }

  /// 🛑 Stop tracking (optional)
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 🔄 Update lastLogin API and Firestore online status
  Future<void> _updateNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();

      // Update HTTP API
      await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId}),
      );

      // Update Firestore online status
      await _firestore.collection('users').doc(userId).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("❌ Online status error: $e");
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

      await _firestore.collection('users').doc(userId).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("❌ Set offline error: $e");
    }
  }
}