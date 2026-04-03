import 'package:flutter/services.dart';

/// Service to interact with Android foreground service for calls
class CallForegroundServiceManager {
  static const MethodChannel _channel =
      MethodChannel('com.marriage.station/call_service');

  /// Start foreground service for a call
  static Future<bool> startCallService({
    required String callType,
    required String callerName,
    required String callId,
    required bool isIncoming,
  }) async {
    try {
      final result = await _channel.invokeMethod('startCallService', {
        'callType': callType,
        'callerName': callerName,
        'callId': callId,
        'isIncoming': isIncoming,
      });
      print('[CallForegroundService] Started: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[CallForegroundService] Error starting service: ${e.message}');
      return false;
    }
  }

  /// Stop foreground service
  static Future<bool> stopCallService() async {
    try {
      final result = await _channel.invokeMethod('stopCallService');
      print('[CallForegroundService] Stopped: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[CallForegroundService] Error stopping service: ${e.message}');
      return false;
    }
  }

  /// Update call notification (for when call connects)
  static Future<bool> updateCallNotification({
    required String callType,
    required String callerName,
    required bool isOngoing,
  }) async {
    try {
      final result = await _channel.invokeMethod('updateCallNotification', {
        'callType': callType,
        'callerName': callerName,
        'isOngoing': isOngoing,
      });
      print('[CallForegroundService] Updated notification: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[CallForegroundService] Error updating notification: ${e.message}');
      return false;
    }
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } on PlatformException catch (e) {
      print('[CallForegroundService] Error checking service: ${e.message}');
      return false;
    }
  }

  static Future<void> startOngoingCall({
    required String callType,
    required String otherUserName,
    required String callId,
  }) async {
    await startCallService(
      callType: callType,
      callerName: otherUserName,
      callId: callId,
      isIncoming: false,
    );
    await updateCallNotification(
      callType: callType,
      callerName: otherUserName,
      isOngoing: true,
    );
  }
}
