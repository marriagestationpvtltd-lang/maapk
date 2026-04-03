import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  Timer? _timer;

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

  /// 🔄 Update lastLogin API
  Future<void> _updateNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final userId = userData["id"].toString();

      await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId}),
      );
    } catch (e) {
      print("❌ Online status error: $e");
    }
  }
}