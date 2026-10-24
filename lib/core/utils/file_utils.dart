import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import 'audio_native_utils.dart';

class FileUtils {
  /// Format byte counts into human-readable strings (e.g. 14.2 MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Sanitizes a string to be a safe filename across Android, Linux, iOS, and Windows.
  static String sanitizeFilename(String input) {
    var clean = input
        .replaceAll(RegExp(r'[\x00-\x1f\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip trailing dots and spaces (forbidden on Windows filesystems)
    clean = clean.replaceAll(RegExp(r'[.\s]+$'), '');

    if (clean.replaceAll('_', '').trim().isEmpty) {
      return 'playlist';
    }

    // Guard against Windows DOS reserved device names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
    const reservedNames = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };
    if (reservedNames.contains(clean.toUpperCase())) {
      return '_$clean';
    }

    return clean;
  }

  /// Generates the standard UTF-8 M3U8 playlist manifest content according to RFC 8216.
  static String generateM3U8Content({
    required String playlistName,
    required List<Track> tracks,
    String? baseDirectoryPath,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:$playlistName');

    for (final track in tracks) {
      if (track.localFilePath == null || track.localFilePath!.isEmpty) {
        continue;
      }

      final durationSec = (track.durationMs / 1000).round();
      final artist = track.artist.isNotEmpty ? track.artist : 'Unknown Artist';
      final title = track.title.isNotEmpty ? track.title : 'Unknown Title';

      buffer.writeln('#EXTINF:$durationSec,$artist - $title');

      String filePath = track.localFilePath!;
      if (baseDirectoryPath != null && filePath.startsWith(baseDirectoryPath)) {
        filePath = p.relative(filePath, from: baseDirectoryPath);
      }
      buffer.writeln(filePath);
    }

    return buffer.toString();
  }

  /// Writes or overwrites a `<playlist_name>.m3u8` manifest file in the target directory.
  static Future<File> writeM3U8File({
    required Directory targetDir,
    required String playlistName,
    required List<Track> tracks,
  }) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final safeName = sanitizeFilename(playlistName);
    final m3u8File = File(p.join(targetDir.path, '$safeName.m3u8'));
    final content = generateM3U8Content(
      playlistName: playlistName,
      tracks: tracks,
      baseDirectoryPath: targetDir.path,
    );

    await m3u8File.writeAsString(content, encoding: utf8, flush: true);
    await AudioNativeUtils.scanFile(m3u8File.path);
    return m3u8File;
  }
}
