import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dashmodel.dart';

class DashboardService {
  static const String _baseUrl = 'https://digitallami.com/api9';

  Future<DashboardResponse> getDashboardData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_dashboard.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DashboardResponse.fromJson(data);
      } else {
        throw Exception('Failed to load dashboard data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}