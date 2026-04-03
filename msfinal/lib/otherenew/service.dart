// lib/services/profile_service.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../otherenew/modelfile.dart';

class ProfileService {
  static const String baseUrl = 'https://digitallami.com/Api2';

  /// Fetch profile data from API
  Future<ProfileResponse> fetchProfile({
    required dynamic myId,
    required dynamic userId
  }) async {
    // Ensure both are converted to strings explicitly
    final String myIdStr = myId.toString();
    final String userIdStr = userId.toString();

    final url = Uri.parse('$baseUrl/other_profile_new.php?myid=$myIdStr&userid=$userIdStr');

    try {
      debugPrint('📡 Fetching profile from: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        debugPrint('📡 Response: ${response.body}');

        if (jsonResponse['status'] == 'success') {
          return ProfileResponse.fromJson(jsonResponse);
        } else {
          throw Exception('API returned error status: ${jsonResponse['status']}');
        }
      } else {
        throw Exception('Failed to load profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      throw Exception('Error fetching profile: $e');
    }
  }


  // In ProfileService class
  Future<Map<String, dynamic>> blockUser({
    required String myId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/block_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'my_id': myId,
          'user_id': userId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unblockUser({
    required String myId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/unblock_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'my_id': myId,
          'user_id': userId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> isUserBlocked({
    required String myId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_block_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'my_id': myId,
          'user_id': userId,
        }),
      );

      final data = jsonDecode(response.body);
      return data['is_blocked'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers({
    required String myId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_blocked_users.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'my_id': myId,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch matched profiles
  Future<List<MatchedProfile>> fetchMatchedProfiles({
    required dynamic userId,
  }) async {
    // Ensure userId is converted to string explicitly
    final String userIdStr = userId.toString();
    final url = Uri.parse('$baseUrl/match.php?userid=$userIdStr');

    try {
      debugPrint('📡 Fetching matched profiles from: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        debugPrint('📡 Matched profiles response: ${response.body}');

        if (jsonResponse['success'] == true) {
          final List<dynamic> matchedUsersJson = jsonResponse['matched_users'] ?? [];
          final matchedProfiles = matchedUsersJson
              .map((json) => MatchedProfile.fromJson(json))
              .toList();
          matchedProfiles.sort((a, b) {
            final matchCompare = b.matchPercent.compareTo(a.matchPercent);
            if (matchCompare != 0) return matchCompare;
            return b.userid.compareTo(a.userid);
          });
          return matchedProfiles;
        } else {
          return [];
        }
      } else {
        debugPrint('❌ Failed to load matched profiles: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching matched profiles: $e');
      return [];
    }
  }

  /// Send photo request
  Future<Map<String, dynamic>> sendPhotoRequest({
    required String myId,
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/send_request.php');

      final response = await http.post(
        url,
        body: {
          'myid': myId,
          'userid': userId,
          'request_type': 'Photo'
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }

      return {
        'status': 'error',
        'message': 'Failed to send photo request',
      };
    } catch (e) {
      debugPrint('❌ Error sending photo request: $e');
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  /// Send chat request
  Future<Map<String, dynamic>> sendChatRequest({
    required String myId,
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/send_request.php');

      final response = await http.post(
        url,
        body: {
          'myid': myId,
          'userid': userId,
          'request_type': "Chat"
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }

      return {
        'status': 'error',
        'message': 'Failed to send chat request',
      };
    } catch (e) {
      debugPrint('❌ Error sending chat request: $e');
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  /// Send like/unlike
  Future<Map<String, dynamic>> sendLike({
    required String myId,
    required String userId,
    required bool like,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/like.php');

      final response = await http.post(
        url,
        body: {
          'myid': myId,
          'userid': userId,
          'like': like ? '1' : '0',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to send like'};
      }
    } catch (e) {
      debugPrint('❌ Error sending like: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptRequest({
    required String myId,
    required String senderId,
    required String type,
  }) async {
    final url = Uri.parse('$baseUrl/accept_request.php');

    final response = await http.post(url, body: {
      'myid': myId,
      'sender_id': senderId,
      'request_type': type,
    });

    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> rejectRequest({
    required String myId,
    required String senderId,
    required String type,
  }) async {
    final url = Uri.parse('$baseUrl/reject_request.php');

    final response = await http.post(url, body: {
      'myid': myId,
      'sender_id': senderId,
      'request_type': type,
    });

    return json.decode(response.body);
  }
}
