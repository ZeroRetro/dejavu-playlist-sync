import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioNativeUtils {
  static const MethodChannel _channel =
      MethodChannel('com.dejavu.player/audio_utils');

  /// Losslessly extracts the pure AAC audio track from a muxed MP4/M4A file
  /// using Android's native MediaExtractor/MediaMuxer.
  /// Drops all video frames so ExoPlayer processes it strictly as pure audio.
  /// Optionally skips an intro segment (e.g. SponsorBlock skit) using [startOffsetMs].
  static Future<bool> stripVideoFromMp4(
    String inputPath, {
    String? outputPath,
    int startOffsetMs = 0,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final target = outputPath ?? inputPath;
      final result = await _channel.invokeMethod<bool>('stripVideoFromMp4', {
        'inputPath': inputPath,
        'outputPath': target,
        'startOffsetMs': startOffsetMs,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('AudioNativeUtils.stripVideoFromMp4 error: $e');
      return false;
    }
  }

  /// Center-crops a 16:9 thumbnail into a 1:1 square JPEG using Android's native Bitmap API.
  static Future<bool> cropThumbnailSquare({
    required String inputPath,
    required String outputPath,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('cropThumbnailSquare', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('AudioNativeUtils.cropThumbnailSquare error: $e');
      return false;
    }
  }

  /// Triggers Android's MediaScannerConnection to index a newly downloaded audio or playlist file
  /// so that external Android players (Poweramp, Musicolet, VLC, Android Auto) detect it immediately.
  static Future<void> scanFile(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanFile', {'path': filePath});
    } catch (e) {
      debugPrint('AudioNativeUtils.scanFile error: $e');
    }
  }
}
