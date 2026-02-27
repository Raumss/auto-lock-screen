import 'package:flutter/services.dart';

class LockService {
  static const _channel = MethodChannel('com.autolock/lock_screen');

  /// Request device admin permission
  static Future<bool> requestAdmin() async {
    final result = await _channel.invokeMethod<bool>('requestAdmin');
    return result ?? false;
  }

  /// Check if device admin is active
  static Future<bool> isAdminActive() async {
    final result = await _channel.invokeMethod<bool>('isAdminActive');
    return result ?? false;
  }

  /// Check if the foreground service is running
  static Future<bool> isServiceRunning() async {
    final result = await _channel.invokeMethod<bool>('isServiceRunning');
    return result ?? false;
  }

  /// Start the auto-lock foreground service
  static Future<void> startService(int timeoutMinutes) async {
    await _channel.invokeMethod('startService', {
      'timeoutMs': timeoutMinutes * 60 * 1000,
    });
  }

  /// Stop the auto-lock foreground service
  static Future<void> stopService() async {
    await _channel.invokeMethod('stopService');
  }

  /// Update the timeout duration while service is running
  static Future<void> updateTimeout(int timeoutMinutes) async {
    await _channel.invokeMethod('updateTimeout', {
      'timeoutMs': timeoutMinutes * 60 * 1000,
    });
  }

  /// Lock the screen immediately
  static Future<bool> lockNow() async {
    final result = await _channel.invokeMethod<bool>('lockNow');
    return result ?? false;
  }

  /// Remove device admin permission
  static Future<void> removeAdmin() async {
    await _channel.invokeMethod('removeAdmin');
  }
}
