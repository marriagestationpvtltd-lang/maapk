import 'package:adminmrz/users/userdetails/userdetailservice.dart';
import 'package:flutter/material.dart';

import 'detailmodel.dart';


class UserDetailsProvider with ChangeNotifier {
  final UserDetailsService _userDetailsService = UserDetailsService();

  UserDetailsData? _userDetails;
  bool _isLoading = false;
  String _error = '';
  int? _userId;
  bool _isUpdating = false;
  String _updateError = '';

  // Activity stats
  ActivityStats? _activityStats;
  bool _isLoadingActivity = false;

  // Photo action
  bool _isPhotoActioning = false;

  // Notification
  bool _isSendingNotification = false;

  UserDetailsData? get userDetails => _userDetails;
  bool get isLoading => _isLoading;
  String get error => _error;
  int? get userId => _userId;
  bool get isUpdating => _isUpdating;
  String get updateError => _updateError;
  ActivityStats? get activityStats => _activityStats;
  bool get isLoadingActivity => _isLoadingActivity;
  bool get isPhotoActioning => _isPhotoActioning;
  bool get isSendingNotification => _isSendingNotification;

  Future<void> fetchUserDetails(int userId, int myId) async {
    _isLoading = true;
    _error = '';
    _userId = userId;
    notifyListeners();

    try {
      final response = await _userDetailsService.getUserDetails(userId, myId);
      if (response.status == 'success') {
        _userDetails = response.data;
      } else {
        _error = 'Failed to load user details';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Also fetch activity stats in parallel
    fetchActivityStats(userId);
  }

  /// Fetch user activity stats (requests, chats, views, matches).
  Future<void> fetchActivityStats(int userId) async {
    _isLoadingActivity = true;
    notifyListeners();
    try {
      _activityStats = await _userDetailsService.getUserActivity(userId);
    } catch (_) {
      _activityStats = ActivityStats.empty();
    } finally {
      _isLoadingActivity = false;
      notifyListeners();
    }
  }

  /// Update a single profile field and refresh the local model on success.
  Future<bool> updateField({
    required String section,
    required String field,
    required String value,
  }) async {
    if (_userId == null) return false;
    _isUpdating = true;
    _updateError = '';
    notifyListeners();

    try {
      final success = await _userDetailsService.updateUserDetail(
        userId: _userId!,
        section: section,
        field: field,
        value: value,
      );
      if (!success) {
        _updateError = 'Update failed. Please try again.';
      }
      _isUpdating = false;
      notifyListeners();
      return success;
    } catch (e) {
      _updateError = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Approve or reject the user's pending profile photo.
  Future<bool> handleProfilePhotoRequest({
    required String action,
    String? reason,
  }) async {
    if (_userId == null) return false;
    _isPhotoActioning = true;
    notifyListeners();
    try {
      final ok = await _userDetailsService.handleProfilePhotoRequest(
        userId: _userId!,
        action: action,
        reason: reason,
      );
      if (ok && _userDetails != null) {
        // Refresh details to reflect new photo status
        final response = await _userDetailsService.getUserDetails(_userId!, _userId!);
        if (response.status == 'success') {
          _userDetails = response.data;
        }
      }
      _isPhotoActioning = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _isPhotoActioning = false;
      notifyListeners();
      return false;
    }
  }

  /// Send an admin notification directly to the user.
  Future<bool> sendAdminNotification({
    required String title,
    required String message,
  }) async {
    if (_userId == null) return false;
    _isSendingNotification = true;
    notifyListeners();
    try {
      final ok = await _userDetailsService.sendAdminNotification(
        userId: _userId!,
        title: title,
        message: message,
      );
      _isSendingNotification = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _isSendingNotification = false;
      notifyListeners();
      return false;
    }
  }

  void clearData() {
    _userDetails = null;
    _error = '';
    _userId = null;
    _updateError = '';
    _activityStats = null;
    notifyListeners();
  }
}