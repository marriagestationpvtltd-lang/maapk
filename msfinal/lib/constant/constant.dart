// lib/constants/agora_constants.dart
class AgoraConstants {
  // Replace these with your actual Agora credentials
  static const String appId = 'a82d7e84e3d34290bea0577ae96c45ae';
  static const String appCertificate = 'f58800495f554da89fcf50f604d82deb';

  // Token expiration time (1 hour)
  static const int tokenExpirationTime = 3600;

  // Firebase Server Key
  static const String firebaseServerKey = 'YOUR_FIREBASE_SERVER_KEY';
}

class AppConstants {
  /// Firestore user ID for the admin account.
  static const String adminUserId = '1';

  /// Returns a deterministic conversation document ID for two participants.
  static String conversationId(String a, String b) =>
      (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  /// Matrimonial profile report reasons shown in the report bottom sheet.
  static const List<String> reportReasons = [
    'नक्कली प्रोफाइल (Fake Profile)',
    'अश्लील वा आपत्तिजनक सामग्री (Inappropriate/Obscene Content)',
    'विवाहित भएर एकल भनेको (Married but claiming to be Single)',
    'आर्थिक ठगी वा धोखाधडी (Financial Fraud or Deception)',
    'गलत उमेर वा व्यक्तिगत जानकारी (False Age or Personal Details)',
    'उत्पीडन वा दुर्व्यवहार (Harassment or Abuse)',
    'अनुचित सम्पर्क व्यवहार (Inappropriate Contact Behavior)',
  ];
}