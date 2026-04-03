class ProfileData {
  final Map<String, dynamic> personalDetail;
  final Map<String, dynamic> familyDetail;
  final Map<String, dynamic> lifestyle;
  final Map<String, dynamic> partner;

  ProfileData({
    required this.personalDetail,
    required this.familyDetail,
    required this.lifestyle,
    required this.partner,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      personalDetail: json['personalDetail'] ?? {},
      familyDetail: json['familyDetail'] ?? {},
      lifestyle: json['lifestyle'] ?? {},
      partner: json['partner'] ?? {},
    );
  }
}

// lib/models/gallery_image.dart
class GalleryImage {
  final String imageUrl;
  final String? caption;
  final String? description;

  GalleryImage({
    required this.imageUrl,
    this.caption,
    this.description,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      imageUrl: json['imageUrl'] ?? '',
      caption: json['caption'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'caption': caption,
      'description': description,
    };
  }
}