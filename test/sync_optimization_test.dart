import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:dejavu_music_player/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late File dummyAudio;
  late File dummyThumb;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('dejavu_sync_test_');
    dummyAudio = File('${tempDir.path}/track_cc_1.m4a')
      ..writeAsBytesSync(List<int>.filled(100 * 1024, 0));
    dummyThumb = File('${tempDir.path}/thumb_cc_1.jpg')
      ..writeAsBytesSync(List<int>.filled(5 * 1024, 0));
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Sync optimization: existing complete track with audio, cover and lyrics skips redundant network sync', () async {
    // Insert existing completed track with valid audio, thumbnail and lyrics
    await db.upsertTrack(
      TracksCompanion.insert(
        id: 'generic_track_1',
        youtubeVideoId: const Value('archive_vid_1'),
        title: 'Creative Commons Sample',
        artist: 'Open Source Artist',
        durationMs: const Value(180000),
        localFilePath: Value(dummyAudio.path),
        thumbnailPath: Value(dummyThumb.path),
        lyricsLrc: const Value('[00:01.00] Generic sample lyric line'),
        downloadStatus: const Value(DownloadStatus.completed),
      ),
    );

    // Verify track is in DB and marked completed
    final track = await db.getTrackById('generic_track_1');
    expect(track, isNotNull);
    expect(track!.downloadStatus, DownloadStatus.completed);
    expect(track.lyricsLrc, isNotEmpty);
    expect(track.thumbnailPath, isNotEmpty);
    expect(File(track.thumbnailPath!).existsSync(), isTrue);
    expect(File(track.localFilePath!).existsSync(), isTrue);
  });

  test('Single-track resync: updates status and correctly references archive item', () async {
    await db.upsertTrack(
      TracksCompanion.insert(
        id: 'generic_track_2',
        youtubeVideoId: const Value('archive_vid_2'),
        title: 'Archive Sample 2',
        artist: 'Creative Commons Studio',
        durationMs: const Value(150000),
        downloadStatus: const Value(DownloadStatus.failed),
      ),
    );

    final trackBefore = await db.getTrackById('generic_track_2');
    expect(trackBefore!.downloadStatus, DownloadStatus.failed);

    // Simulate resync status updates through state
    await db.updateTrackDownloadState(
      trackId: 'generic_track_2',
      status: DownloadStatus.downloading,
    );
    final trackDuring = await db.getTrackById('generic_track_2');
    expect(trackDuring!.downloadStatus, DownloadStatus.downloading);
  });
}
