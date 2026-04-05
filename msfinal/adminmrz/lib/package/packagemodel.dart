class PackageListResponse {
  final bool success;
  final int count;
  final List<Package> data;

  PackageListResponse({
    required this.success,
    required this.count,
    required this.data,
  });

  factory PackageListResponse.fromJson(Map<String, dynamic> json) {
    return PackageListResponse(
      success: json['success'] ?? false,
      count: json['count'] ?? 0,
      data: List<Package>.from(
          (json['data'] ?? []).map((x) => Package.fromJson(x))),
    );
  }
}

class Package {
  final int id;
  final String name;
  final String duration;
  final String description;
  final String price;

  Package({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.price,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration': duration,
      'description': description,
      'price': price,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'duration': durationInMonths.toString(),
      'description': description,
      'price': numericPrice.toStringAsFixed(2),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'id': id,
      'name': name,
      'duration': durationInMonths.toString(),
      'description': description,
      'price': numericPrice.toStringAsFixed(2),
    };
  }

  // Extract numeric duration (e.g., "90 Month" -> 90)
  int get durationInMonths {
    try {
      return int.parse(duration.replaceAll(' Month', '').trim());
    } catch (e) {
      return 0;
    }
  }

  // Extract numeric price (e.g., "Rs 300.00" -> 300.0)
  double get numericPrice {
    try {
      return double.parse(
          price.replaceAll('Rs ', '').replaceAll(',', '').trim());
    } catch (e) {
      return 0.0;
    }
  }
}

class CreatePackageResponse {
  final bool success;
  final String message;
  final int packageId;

  CreatePackageResponse({
    required this.success,
    required this.message,
    required this.packageId,
  });

  factory CreatePackageResponse.fromJson(Map<String, dynamic> json) {
    return CreatePackageResponse(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      packageId: json['package_id'] is int ? json['package_id'] : 0,
    );
  }
}