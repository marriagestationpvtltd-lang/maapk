class AppConstants {
  static const String adminUserId = '1';

  static const List<String> reportReasons = [
    'Fake profile',
    'Inappropriate content',
    'Harassment or abuse',
    'Spam',
    'Scam or fraud',
    'Offensive language',
    'Other',
  ];

  static String conversationId(String a, String b) {
    return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
  }
}
