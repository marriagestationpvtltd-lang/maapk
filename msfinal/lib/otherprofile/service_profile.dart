import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../Home/Screen/profilecard.dart';
import 'modelprofile.dart';

class ProfileService {
  static const String _baseUrl = "https://digitallami.com/Api2";

  Future<Map<String, dynamic>> fetchProfileData(int userId, int myid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/other_profile.php?userid=$userId&myid=$myid'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load profile: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> checkPhotoPrivacy(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/check_photo_privacy.php?userid=$userId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'show_blur': true, 'has_requested': false};
    } catch (e) {
      return {'show_blur': true, 'has_requested': false};
    }
  }

  Future<List<GalleryImage>> fetchGalleryImages(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_gallery.php?userid=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final gallery = data['gallery'] as List;
          return gallery.map((item) => GalleryImage.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendRequest({
    required int senderId,
    required int receiverId,
    required String requestType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'request_type': requestType,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to send request');
    } catch (e) {
      throw Exception('Error sending request: $e');
    }
  }

  static Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final userData = json.decode(userDataString);
      return int.tryParse(userData["id"].toString());
    }
    return null;
  }
}