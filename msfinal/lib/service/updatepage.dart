import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateService {
  static const String baseUrl = "http://digitallami.com/Api2"; // change to your domain

  // Reusable function to update page number
  static Future<bool> updatePageNumber({
    required String userId,
    required int pageNo,
  }) async {
    try {
      final uri = Uri.parse(
          "$baseUrl/update_pageno.php?user_id=$userId&pageno=$pageNo");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          print("Page updated: ${data['pageno']}");
          return true;
        } else {
          print("Error: ${data['message']}");
          return false;
        }
      } else {
        print("Server Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Exception: $e");
      return false;
    }
  }
}
