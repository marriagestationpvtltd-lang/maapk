import 'package:adminmrz/payment/paymentmodel.dart';
import 'package:adminmrz/payment/paymentservice.dart';
import 'package:flutter/material.dart';


class PaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  PaymentSummary? _summary;
  List<Payment> _allPayments = [];
  List<Payment> _filteredPayments = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';
  String _paymentMethodFilter = 'all';
  String _statusFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  PaymentSummary? get summary => _summary;
  List<Payment> get payments => _filteredPayments;
  List<Payment> get allPayments => _allPayments;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  String get paymentMethodFilter => _paymentMethodFilter;
  String get statusFilter => _statusFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  Future<void> fetchPayments() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await _paymentService.getPaymentHistory();
      _summary = response.summary;
      _allPayments = response.data;
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFilteredPayments() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await _paymentService.getFilteredPayments(
        startDate: _startDate,
        endDate: _endDate,
        paymentMethod: _paymentMethodFilter != 'all' ? _paymentMethodFilter : null,
        status: _statusFilter != 'all' ? _statusFilter : null,
      );

      _summary = response.summary;
      _allPayments = response.data;
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void setPaymentMethodFilter(String method) {
    _paymentMethodFilter = method;
    _applyFilters();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _applyFilters();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _paymentMethodFilter = 'all';
    _statusFilter = 'all';
    _startDate = null;
    _endDate = null;
    _applyFilters();
  }

  void _applyFilters() {
    List<Payment> filtered = List<Payment>.from(_allPayments);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((payment) {
        return payment.fullName.toLowerCase().contains(_searchQuery) ||
            payment.packageName.toLowerCase().contains(_searchQuery) ||
            payment.paidBy.toLowerCase().contains(_searchQuery) ||
            payment.userId.toString().contains(_searchQuery);
      }).toList();
    }

    // Apply payment method filter
    if (_paymentMethodFilter != 'all') {
      filtered = filtered.where((payment) =>
      payment.paidBy.toLowerCase() == _paymentMethodFilter.toLowerCase())
          .toList();
    }

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((payment) =>
      payment.packageStatus.toLowerCase() == _statusFilter.toLowerCase())
          .toList();
    }

    // Apply date filter
    if (_startDate != null) {
      filtered = filtered.where((payment) =>
          payment.purchaseDateTime.isAfter(_startDate!.subtract(const Duration(days: 1))))
          .toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((payment) =>
          payment.purchaseDateTime.isBefore(_endDate!.add(const Duration(days: 1))))
          .toList();
    }

    _filteredPayments = filtered;
    notifyListeners();
  }

  // Get unique payment methods from data
  List<String> getPaymentMethods() {
    final methods = _allPayments.map((p) => p.paidBy).toSet().toList();
    methods.sort();
    return methods;
  }

  // Get status options
  List<String> getStatusOptions() {
    return ['active', 'expired', 'pending'];
  }

  // Get payment statistics by method
  Map<String, double> getPaymentMethodStats() {
    final Map<String, double> stats = {};

    for (var payment in _allPayments) {
      final method = payment.paidBy;
      final price = payment.numericPrice;

      stats[method] = (stats[method] ?? 0) + price;
    }

    return stats;
  }

  // Get payments by user
  List<Payment> getPaymentsByUserId(int userId) {
    return _allPayments.where((p) => p.userId == userId).toList();
  }

  // Get payments by package
  List<Payment> getPaymentsByPackageId(int packageId) {
    return _allPayments.where((p) => p.packageId == packageId).toList();
  }

  // Calculate total filtered amount
  double get filteredTotalAmount {
    return _filteredPayments.fold(0.0, (sum, payment) => sum + payment.numericPrice);
  }

  // Get monthly earnings
  Map<String, double> getMonthlyEarnings() {
    final Map<String, double> monthly = {};

    for (var payment in _allPayments) {
      final monthKey = '${payment.purchaseDateTime.year}-${payment.purchaseDateTime.month.toString().padLeft(2, '0')}';
      monthly[monthKey] = (monthly[monthKey] ?? 0) + payment.numericPrice;
    }

    return monthly;
  }
}