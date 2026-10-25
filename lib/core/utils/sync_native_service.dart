import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart bridge controlling the Android Foreground Data Sync Service and CPU WakeLock.
class SyncNativeService {
  static const MethodChannel _channel =
      MethodChannel('com.dejavu.player/sync_service');

  /// Starts the native foreground service with an ongoing notification and CPU wake lock.
  static Future<void> startSyncService({
    required String title,
    required String message,
    int progress = 0,
    int total = 0,
    bool indeterminate = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startSyncService', {
        'title': title,
        'message': message,
        'progress': progress,
        'total': total,
        'indeterminate': indeterminate,
      });
    } catch (e) {
      debugPrint('SyncNativeService.startSyncService error: $e');
    }
  }

  /// Updates the native foreground notification progress and status.
  static Future<void> updateSyncProgress({
    required String title,
    required String message,
    int progress = 0,
    int total = 0,
    bool indeterminate = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateSyncProgress', {
        'title': title,
        'message': message,
        'progress': progress,
        'total': total,
        'indeterminate': indeterminate,
      });
    } catch (e) {
      debugPrint('SyncNativeService.updateSyncProgress error: $e');
    }
  }

  /// Stops the native foreground service, dismisses notification, and releases the CPU wake lock.
  static Future<void> stopSyncService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopSyncService');
    } catch (e) {
      debugPrint('SyncNativeService.stopSyncService error: $e');
    }
  }
}
