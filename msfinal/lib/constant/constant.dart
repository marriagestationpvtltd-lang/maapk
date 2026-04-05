// lib/constants/agora_constants.dart

/// Central API configuration.
/// तल तीन option छन् — जुन चाहिन्छ त्यो uncomment गर्नुस्, बाकी comment राख्नुस्।
class ApiConfig {
  // ── Live Server ──────────────────────────────────────────────────────────
  static const String baseUrl    = 'https://digitallami.com/Api2';
  static const String baseUrl3   = 'https://digitallami.com/Api3';
  static const String requestUrl = 'https://digitallami.com/request';
  static const String appUrl     = 'https://digitallami.com/app.php';

  // ── Android Emulator (10.0.2.2) ──────────────────────────────────────────
  // static const String baseUrl    = 'http://10.0.2.2/Api2';
  // static const String baseUrl3   = 'http://10.0.2.2/Api3';
  // static const String requestUrl = 'http://10.0.2.2/request';
  // static const String appUrl     = 'http://10.0.2.2/app.php';

  // ── Physical Phone (USB) — आफ्नो PC को IP राख्नुस् ─────────────────────
  // static const String baseUrl    = 'http://<YOUR_PC_IP>/Api2';
  // static const String baseUrl3   = 'http://<YOUR_PC_IP>/Api3';
  // static const String requestUrl = 'http://<YOUR_PC_IP>/request';
  // static const String appUrl     = 'http://<YOUR_PC_IP>/app.php';
}

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
    'Fake Profile',
    'Inappropriate/Obscene Content',
    'Married but claiming to be Single',
    'Financial Fraud or Deception',
    'False Age or Personal Details',
    'Harassment or Abuse',
    'Inappropriate Contact Behavior',
  ];
}