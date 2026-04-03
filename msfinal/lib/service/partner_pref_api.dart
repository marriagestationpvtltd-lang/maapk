import 'dart:convert';
import 'package:http/http.dart' as http;

class UserPartnerPreferenceService {
  final String baseUrl;

  UserPartnerPreferenceService({required this.baseUrl});

  /// Save or update partner preference
  Future<Map<String, dynamic>> savePartnerPreference({
    required int userId,
    required String ageFrom,
    required String ageTo,
    required String heightFrom,
    required String heightTo,
    required String maritalStatus,
    required String religion,
    String? community,
    String? motherTongue,
    String? country,
    String? state,
    String? district,
    String? education,
    String? occupation,
  }) async {
    final url = Uri.parse(baseUrl);

    // Prepare request body
    final body = <String, String>{
      'user_id': userId.toString(),
      'age_from': ageFrom,
      'age_to': ageTo,
      'height_from': heightFrom,
      'height_to': heightTo,
      'marital_status': maritalStatus,
      'religion': religion,
      if (community != null) 'community': community,
      if (motherTongue != null) 'mother_tongue': motherTongue,
      if (country != null) 'country': country,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (education != null) 'education': education,
      if (occupation != null) 'occupation': occupation,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'status': 'error',
          'message': 'Server returned status code ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
