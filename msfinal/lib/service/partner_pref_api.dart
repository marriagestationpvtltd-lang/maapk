import 'dart:convert';
import 'package:http/http.dart' as http;

class UserPartnerPreferenceService {
  final String saveUrl;
  final String fetchUrl;

  UserPartnerPreferenceService({
    this.saveUrl = 'https://digitallami.com/Api2/user_partner.php',
    this.fetchUrl = 'https://digitallami.com/Api2/get_partner_preferences.php',
  });

  Future<Map<String, dynamic>?> fetchPartnerPreference({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$fetchUrl?userid=$userId'),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }

    return null;
  }

  Future<Map<String, dynamic>> savePartnerPreference({
    required int userId,
    required String ageFrom,
    required String ageTo,
    required String heightFrom,
    required String heightTo,
    required String maritalStatus,
    required String religion,
    List<String> countryIds = const [],
    List<String> stateIds = const [],
    List<String> cityIds = const [],
    String? community,
    String? motherTongue,
    String? country,
    String? state,
    String? district,
    String? education,
    String? occupation,
  }) async {
    final url = Uri.parse(saveUrl);

    final body = <String, dynamic>{
      'userid': userId.toString(),
      'minage': ageFrom,
      'maxage': ageTo,
      'minheight': heightFrom,
      'maxheight': heightTo,
      'maritalstatus': maritalStatus,
      'profilewithchild': '',
      'familytype': '',
      'religion': religion,
      'caste': community ?? '',
      'subcaste': '',
      'mothertoungue': motherTongue ?? '',
      'herscopeblief': '',
      'manglik': '',
      'country': countryIds.join(','),
      'state': stateIds.join(','),
      'city': cityIds.join(','),
      'qualification': education ?? '',
      'educationmedium': '',
      'proffession': occupation ?? '',
      'workingwith': '',
      'annualincome': '',
      'diet': '',
      'smokeaccept': '',
      'drinkaccept': '',
      'disabilityaccept': '',
      'complexion': '',
      'bodytype': '',
      'otherexpectation': '',
      'country_names': country ?? '',
      'state_names': state ?? '',
      'district_names': district ?? '',
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
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
