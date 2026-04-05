class Document {
  final int userId;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String status;
  final int isVerified;
  final int documentId;
  final String documentType;
  final String documentIdNumber;
  final String photo;

  Document({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.status,
    required this.isVerified,
    required this.documentId,
    required this.documentType,
    required this.documentIdNumber,
    required this.photo,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      status: json['status'] ?? '',
      isVerified: json['isVerified'] ?? 0,
      documentId: json['document_id'] ?? 0,
      documentType: json['documenttype'] ?? '',
      documentIdNumber: json['documentidnumber'] ?? '',
      photo: json['photo'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';
  String get fullPhotoUrl => photo;
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}