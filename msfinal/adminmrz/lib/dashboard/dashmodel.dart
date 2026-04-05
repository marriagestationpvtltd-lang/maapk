class DashboardResponse {
  final bool success;
  final DashboardData dashboard;

  DashboardResponse({
    required this.success,
    required this.dashboard,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      success: json['success'] ?? false,
      dashboard: DashboardData.fromJson(json['dashboard'] ?? {}),
    );
  }
}

class DashboardData {
  final UserStats users;
  final AddressStats permanentAddress;
  final PaymentStats payments;

  DashboardData({
    required this.users,
    required this.permanentAddress,
    required this.payments,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      users: UserStats.fromJson(json['users'] ?? {}),
      permanentAddress: AddressStats.fromJson(json['permanent_address'] ?? {}),
      payments: PaymentStats.fromJson(json['payments'] ?? {}),
    );
  }
}

class UserStats {
  final int total;
  final int todayRegistered;
  final int thisMonthRegistered;
  final int verified;
  final int unverified;
  final int active;
  final int online;
  final List<TypeCount> byType;
  final List<GenderCount> byGender;
  final List<PageCount> byPageno;

  UserStats({
    required this.total,
    required this.todayRegistered,
    required this.thisMonthRegistered,
    required this.verified,
    required this.unverified,
    required this.active,
    required this.online,
    required this.byType,
    required this.byGender,
    required this.byPageno,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      total: json['total'] is int ? json['total'] : 0,
      todayRegistered: json['today_registered'] is int ? json['today_registered'] : 0,
      thisMonthRegistered: json['this_month_registered'] is int ? json['this_month_registered'] : 0,
      verified: json['verified'] is int ? json['verified'] : 0,
      unverified: json['unverified'] is int ? json['unverified'] : 0,
      active: json['active'] is int ? json['active'] : 0,
      online: json['online'] is int ? json['online'] : 0,
      byType: List<TypeCount>.from(
        (json['by_type'] ?? []).map((x) => TypeCount.fromJson(x)),
      ),
      byGender: List<GenderCount>.from(
        (json['by_gender'] ?? []).map((x) => GenderCount.fromJson(x)),
      ),
      byPageno: List<PageCount>.from(
        (json['by_pageno'] ?? []).map((x) => PageCount.fromJson(x)),
      ),
    );
  }
}

class TypeCount {
  final String usertype;
  final int total;

  TypeCount({
    required this.usertype,
    required this.total,
  });

  factory TypeCount.fromJson(Map<String, dynamic> json) {
    return TypeCount(
      usertype: json['usertype']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class GenderCount {
  final String gender;
  final int total;

  GenderCount({
    required this.gender,
    required this.total,
  });

  factory GenderCount.fromJson(Map<String, dynamic> json) {
    return GenderCount(
      gender: json['gender']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class PageCount {
  final int pageno;
  final int total;

  PageCount({
    required this.pageno,
    required this.total,
  });

  factory PageCount.fromJson(Map<String, dynamic> json) {
    return PageCount(
      pageno: json['pageno'] is int ? json['pageno'] : 0,
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class AddressStats {
  final int totalWithAddress;
  final List<CountryCount> byCountry;
  final List<StateCount> byState;
  final List<CityCount> byCity;
  final List<ResidentialStatusCount> byResidentialStatus;

  AddressStats({
    required this.totalWithAddress,
    required this.byCountry,
    required this.byState,
    required this.byCity,
    required this.byResidentialStatus,
  });

  factory AddressStats.fromJson(Map<String, dynamic> json) {
    return AddressStats(
      totalWithAddress: json['total_with_address'] is int ? json['total_with_address'] : 0,
      byCountry: List<CountryCount>.from(
        (json['by_country'] ?? []).map((x) => CountryCount.fromJson(x)),
      ),
      byState: List<StateCount>.from(
        (json['by_state'] ?? []).map((x) => StateCount.fromJson(x)),
      ),
      byCity: List<CityCount>.from(
        (json['by_city'] ?? []).map((x) => CityCount.fromJson(x)),
      ),
      byResidentialStatus: List<ResidentialStatusCount>.from(
        (json['by_residential_status'] ?? []).map((x) => ResidentialStatusCount.fromJson(x)),
      ),
    );
  }
}

class CountryCount {
  final String country;
  final int total;

  CountryCount({
    required this.country,
    required this.total,
  });

  factory CountryCount.fromJson(Map<String, dynamic> json) {
    return CountryCount(
      country: json['country']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class StateCount {
  final String state;
  final int total;

  StateCount({
    required this.state,
    required this.total,
  });

  factory StateCount.fromJson(Map<String, dynamic> json) {
    return StateCount(
      state: json['state']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class CityCount {
  final String city;
  final int total;

  CityCount({
    required this.city,
    required this.total,
  });

  factory CityCount.fromJson(Map<String, dynamic> json) {
    return CityCount(
      city: json['city']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class ResidentialStatusCount {
  final String residentalstatus;
  final int total;

  ResidentialStatusCount({
    required this.residentalstatus,
    required this.total,
  });

  factory ResidentialStatusCount.fromJson(Map<String, dynamic> json) {
    return ResidentialStatusCount(
      residentalstatus: json['residentalstatus']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class PaymentStats {
  final int totalSold;
  final int activePackages;
  final int expiredPackages;
  final String totalEarning;
  final String todayEarning;
  final String thisMonthEarning;
  final List<PaymentMethodCount> byMethod;
  final BestSellingPackage bestSellingPackage;

  PaymentStats({
    required this.totalSold,
    required this.activePackages,
    required this.expiredPackages,
    required this.totalEarning,
    required this.todayEarning,
    required this.thisMonthEarning,
    required this.byMethod,
    required this.bestSellingPackage,
  });

  factory PaymentStats.fromJson(Map<String, dynamic> json) {
    // Handle best_selling_package which might be false (bool) instead of a map
    dynamic bestPackageData = json['best_selling_package'];
    BestSellingPackage bestPackage;

    if (bestPackageData is Map<String, dynamic>) {
      bestPackage = BestSellingPackage.fromJson(bestPackageData);
    } else {
      // Return a default/empty package when it's false or any other type
      bestPackage = BestSellingPackage(
        name: 'No package data',
        total: 0,
      );
    }

    return PaymentStats(
      totalSold: json['total_sold'] is int ? json['total_sold'] : 0,
      activePackages: json['active_packages'] is int ? json['active_packages'] : 0,
      expiredPackages: json['expired_packages'] is int ? json['expired_packages'] : 0,
      totalEarning: json['total_earning']?.toString() ?? 'Rs 0.00',
      todayEarning: json['today_earning']?.toString() ?? 'Rs 0.00',
      thisMonthEarning: json['this_month_earning']?.toString() ?? 'Rs 0.00',
      byMethod: List<PaymentMethodCount>.from(
        (json['by_method'] ?? []).map((x) => PaymentMethodCount.fromJson(x)),
      ),
      bestSellingPackage: bestPackage,
    );
  }

  double get numericTotalEarning {
    try {
      return double.parse(totalEarning.replaceAll('Rs ', '').replaceAll(',', '').trim());
    } catch (e) {
      return 0.0;
    }
  }
}

class PaymentMethodCount {
  final String paidby;
  final int total;

  PaymentMethodCount({
    required this.paidby,
    required this.total,
  });

  factory PaymentMethodCount.fromJson(Map<String, dynamic> json) {
    return PaymentMethodCount(
      paidby: json['paidby']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class BestSellingPackage {
  final String name;
  final int total;

  BestSellingPackage({
    required this.name,
    required this.total,
  });

  factory BestSellingPackage.fromJson(Map<String, dynamic> json) {
    return BestSellingPackage(
      name: json['name']?.toString() ?? '',
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}