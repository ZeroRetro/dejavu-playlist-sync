import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// Helper for seeding clean, Creative Commons fixtures for screenshots and testing.
class DemoSeeder {
  static Future<void> seedCreativeCommonsShowcase(AppDatabase db) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'dejavu_audio'));
    final thumbDir = Directory(p.join(appDir.path, 'dejavu_thumbs'));

    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

    // 1. Extract bundled icon as high-res cover thumbnail
    final thumbFile = File(p.join(thumbDir.path, 'demo_cc_cover.png'));
    if (!thumbFile.existsSync()) {
      final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
      await thumbFile.writeAsBytes(iconBytes.buffer.asUint8List());
    }

    // 2. Generate a valid 44.1kHz stereo PCM WAV file (15 seconds) for ExoPlayer playback
    final audioFile = File(p.join(audioDir.path, 'demo_cc_track.wav'));
    if (!audioFile.existsSync()) {
      const sampleRate = 44100;
      const channels = 2;
      const bitsPerSample = 16;
      const durationSeconds = 15;
      const dataSize = durationSeconds * sampleRate * channels * (bitsPerSample ~/ 8);
      const fileSize = 36 + dataSize;

      final wavBuffer = BytesBuilder();
      // RIFF header
      wavBuffer.add(Uint8List.fromList('RIFF'.codeUnits));
      final fileSizeBytes = ByteData(4)..setUint32(0, fileSize, Endian.little);
      wavBuffer.add(fileSizeBytes.buffer.asUint8List());
      wavBuffer.add(Uint8List.fromList('WAVE'.codeUnits));

      // fmt subchunk
      wavBuffer.add(Uint8List.fromList('fmt '.codeUnits));
      final fmtSize = ByteData(4)..setUint32(0, 16, Endian.little);
      wavBuffer.add(fmtSize.buffer.asUint8List());
      final audioFormat = ByteData(2)..setUint16(0, 1, Endian.little); // PCM
      wavBuffer.add(audioFormat.buffer.asUint8List());
      final numChannels = ByteData(2)..setUint16(0, channels, Endian.little);
      wavBuffer.add(numChannels.buffer.asUint8List());
      final sampleRateBytes = ByteData(4)..setUint32(0, sampleRate, Endian.little);
      wavBuffer.add(sampleRateBytes.buffer.asUint8List());
      const byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
      final byteRateBytes = ByteData(4)..setUint32(0, byteRate, Endian.little);
      wavBuffer.add(byteRateBytes.buffer.asUint8List());
      const blockAlign = channels * (bitsPerSample ~/ 8);
      final blockAlignBytes = ByteData(2)..setUint16(0, blockAlign, Endian.little);
      wavBuffer.add(blockAlignBytes.buffer.asUint8List());
      final bitsPerSampleBytes = ByteData(2)..setUint16(0, bitsPerSample, Endian.little);
      wavBuffer.add(bitsPerSampleBytes.buffer.asUint8List());

      // data subchunk
      wavBuffer.add(Uint8List.fromList('data'.codeUnits));
      final dataSizeBytes = ByteData(4)..setUint32(0, dataSize, Endian.little);
      wavBuffer.add(dataSizeBytes.buffer.asUint8List());
      wavBuffer.add(Uint8List(dataSize)); // zero silence bytes

      await audioFile.writeAsBytes(wavBuffer.toBytes());
    }

    const playlistId = 'demo_cc_showcase';
    const plUrl = 'https://music.youtube.com/playlist?list=PL_OPEN_MEDIA_SHOWCASE';

    // 3. Upsert Playlist
    await db.createPlaylist(
      PlaylistsCompanion.insert(
        id: playlistId,
        name: 'Creative Commons Showcase',
        isYoutubeSynced: const Value(true),
        youtubePlaylistId: const Value('PL_OPEN_MEDIA_SHOWCASE'),
        youtubePlaylistUrl: const Value(plUrl),
        thumbnailPath: Value(thumbFile.path),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );

    // 4. Upsert Tracks
    const lyrics = '''
[00:00.00]♪ Ambient Strings ♪
[00:03.50]Echoes in the cold mountain wind
[00:06.80]Through the barren valley of stone
[00:09.20]A solitary wanderer walks on
[00:11.50]Searching for the forgotten light
[00:13.00]Wings unfurl against the dawn
''';

    final tracks = [
      (
        id: 'cc_track_1',
        title: 'Sintel Theme',
        artist: 'Jan Morgenstern',
        duration: 253000,
        lyrics: lyrics,
      ),
      (
        id: 'cc_track_2',
        title: 'Big Buck Bunny Suite',
        artist: 'Blender Foundation',
        duration: 432000,
        lyrics: null,
      ),
      (
        id: 'cc_track_3',
        title: 'Canon in D Major',
        artist: 'Johann Pachelbel',
        duration: 312000,
        lyrics: null,
      ),
      (
        id: 'cc_track_4',
        title: 'Tears of Steel (Open Sound)',
        artist: 'Joris Hermy',
        duration: 180000,
        lyrics: null,
      ),
    ];

    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      await db.upsertTrack(
        TracksCompanion.insert(
          id: t.id,
          youtubeVideoId: Value('vid_${t.id}'),
          title: t.title,
          artist: t.artist,
          durationMs: Value(t.duration),
          localFilePath: Value(audioFile.path),
          thumbnailPath: Value(thumbFile.path),
          lyricsLrc: Value(t.lyrics),
          downloadStatus: const Value(DownloadStatus.completed),
        ),
      );

      await db.linkTrackToPlaylist(
        playlistId: playlistId,
        trackId: t.id,
        position: i,
      );
    }
  }
}
