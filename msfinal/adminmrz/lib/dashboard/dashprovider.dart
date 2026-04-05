import 'package:flutter/material.dart';

import 'dashmodel.dart';
import 'dashservice.dart';


class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();

  DashboardData? _dashboardData;
  bool _isLoading = false;
  String _error = '';

  DashboardData? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await _dashboardService.getDashboardData();
      if (response.success) {
        _dashboardData = response.dashboard;
      } else {
        _error = 'Failed to load dashboard data';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}