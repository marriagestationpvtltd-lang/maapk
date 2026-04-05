import 'package:adminmrz/package/packagemodel.dart';
import 'package:adminmrz/package/packageservice.dart';
import 'package:flutter/material.dart';


class PackageProvider with ChangeNotifier {
  final PackageService _packageService = PackageService();

  List<Package> _packages = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';

  List<Package> get packages => _filteredPackages;
  List<Package> get allPackages => _packages;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get count => _packages.length;
  String get searchQuery => _searchQuery;

  List<Package> get _filteredPackages {
    if (_searchQuery.isEmpty) return _packages;

    return _packages.where((package) {
      return package.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          package.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          package.price.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> fetchPackages() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await _packageService.getPackages();
      _packages = response.data;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPackage({
    required String name,
    required int duration,
    required String description,
    required double price,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final package = Package(
        id: 0, // Will be assigned by server
        name: name,
        duration: '$duration Month',
        description: description,
        price: 'Rs ${price.toStringAsFixed(2)}',
      );

      final response = await _packageService.createPackage(package);

      if (response.success) {
        // Refresh packages list
        await fetchPackages();
        return true;
      } else {
        _error = response.message;
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePackage(Package package) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _packageService.updatePackage(package);

      if (success) {
        // Update local list
        final index = _packages.indexWhere((p) => p.id == package.id);
        if (index != -1) {
          _packages[index] = package;
          notifyListeners();
        }
        return true;
      } else {
        _error = 'Failed to update package';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePackage(int packageId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _packageService.deletePackage(packageId);

      if (success) {
        // Remove from local list
        _packages.removeWhere((p) => p.id == packageId);
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to delete package';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}