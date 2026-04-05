import 'package:flutter/material.dart';

class PaymentHistoryResponse {
  final bool success;
  final PaymentSummary summary;
  final List<Payment> data;

  PaymentHistoryResponse({
    required this.success,
    required this.summary,
    required this.data,
  });

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryResponse(
      success: json['success'] ?? false,
      summary: PaymentSummary.fromJson(json['summary'] ?? {}),
      data: List<Payment>.from(
          (json['data'] ?? []).map((x) => Payment.fromJson(x))),
    );
  }
}

class PaymentSummary {
  final int totalPackagesSold;
  final String totalEarning;
  final String topPaymentMethod;
  final int activePackages;
  final int expiredPackages;

  PaymentSummary({
    required this.totalPackagesSold,
    required this.totalEarning,
    required this.topPaymentMethod,
    required this.activePackages,
    required this.expiredPackages,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalPackagesSold: json['total_packages_sold'] is int
          ? json['total_packages_sold']
          : int.tryParse(json['total_packages_sold'].toString()) ?? 0,
      totalEarning: json['total_earning']?.toString() ?? 'Rs 0.00',
      topPaymentMethod: json['top_payment_method']?.toString() ?? 'N/A',
      activePackages: json['active_packages'] is int
          ? json['active_packages']
          : int.tryParse(json['active_packages'].toString()) ?? 0,
      expiredPackages: json['expired_packages'] is int
          ? json['expired_packages']
          : int.tryParse(json['expired_packages'].toString()) ?? 0,
    );
  }

  double get numericEarning {
    try {
      return double.parse(totalEarning.replaceAll('Rs ', '').trim());
    } catch (e) {
      return 0.0;
    }
  }
}

class Payment {
  final int id;
  final String paidBy;
  final int userId;
  final int packageId;
  final String purchaseDate;
  final String expireDate;
  final String firstName;
  final String lastName;
  final String email;
  final String packageName;
  final String packagePrice;
  final String packageStatus;

  Payment({
    required this.id,
    required this.paidBy,
    required this.userId,
    required this.packageId,
    required this.purchaseDate,
    required this.expireDate,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.packageName,
    required this.packagePrice,
    required this.packageStatus,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      paidBy: json['paidby']?.toString() ?? '',
      userId: json['userid'] is int ? json['userid'] : int.tryParse(json['userid'].toString()) ?? 0,
      packageId: json['packageid'] is int
          ? json['packageid']
          : int.tryParse(json['packageid'].toString()) ?? 0,
      purchaseDate: json['purchasedate']?.toString() ?? '',
      expireDate: json['expiredate']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      packageName: json['package_name']?.toString() ?? '',
      packagePrice: json['package_price']?.toString() ?? '',
      packageStatus: json['package_status']?.toString() ?? 'active',
    );
  }

  String get fullName => '$firstName $lastName';

  String get invoiceNumber => 'INV-${id.toString().padLeft(6, '0')}';

  String get displayInitials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (fullName.isNotEmpty) return fullName[0].toUpperCase();
    return '?';
  }

  double get numericPrice {
    try {
      return double.parse(packagePrice.replaceAll('Rs ', '').trim());
    } catch (e) {
      return 0.0;
    }
  }

  DateTime get purchaseDateTime {
    try {
      return DateTime.parse(purchaseDate);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime get expireDateTime {
    try {
      return DateTime.parse(expireDate);
    } catch (e) {
      return DateTime.now().add(const Duration(days: 365));
    }
  }

  String get formattedPurchaseDate {
    final date = purchaseDateTime;
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedExpireDate {
    final date = expireDateTime;
    return '${date.day}/${date.month}/${date.year}';
  }

  bool get isExpired => packageStatus.toLowerCase() == 'expired';
  bool get isActive => packageStatus.toLowerCase() == 'active';

  Color get statusColor {
    switch (packageStatus.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // For PDF generation
  Map<String, dynamic> toInvoiceMap() {
    return {
      'invoice_id': 'INV-${id.toString().padLeft(6, '0')}',
      'customer_name': fullName,
      'customer_email': email,
      'customer_id': userId,
      'package_name': packageName,
      'package_price': packagePrice,
      'payment_method': paidBy,
      'purchase_date': purchaseDate,
      'expire_date': expireDate,
      'status': packageStatus,
    };
  }
}