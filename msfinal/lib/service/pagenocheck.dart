import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constant/constant.dart';

class PageService {
  static const String apiUrl = "${ApiConfig.baseUrl}/get_page.php";

  static Future<int?> getPageNo(int userId) async {
    try {
      final url = Uri.parse("$apiUrl?user_id=$userId");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json["status"] == "success") {
          return int.tryParse(json["data"]["pageno"].toString());
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
