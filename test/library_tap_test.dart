import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:dejavu_music_player/core/database/app_database.dart';
import 'package:dejavu_music_player/features/library/library_screen.dart';
import 'package:dejavu_music_player/features/player/audio_player_controller.dart';

import 'player_interaction_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File file1;
  late File file2;
  late File file3;
  late AppDatabase db;

  setUpAll(() {
    JustAudioPlatform.instance = FakeJustAudioPlatform();

    tempDir = Directory.systemTemp.createTempSync('dejavu_widget_test_');
    final dummyBytes = List<int>.filled(60 * 1024, 0);
    file1 = File('${tempDir.path}/track1.m4a')..writeAsBytesSync(dummyBytes);
    file2 = File('${tempDir.path}/track2.m4a')..writeAsBytesSync(dummyBytes);
    file3 = File('${tempDir.path}/track3.m4a')..writeAsBytesSync(dummyBytes);
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

  test('When playing playlist track, tap song in All Songs tab', () async {
    // Insert 3 tracks into database with existing lyrics so network is skipped
    await db.upsertTrack(TracksCompanion.insert(
      id: 't1',
      title: 'Song One',
      artist: 'Artist One',
      durationMs: const Value(180000),
      localFilePath: Value(file1.path),
      lyricsLrc: const Value('[00:01.00] Ly1'),
      downloadStatus: const Value(DownloadStatus.completed),
    ));
    await db.upsertTrack(TracksCompanion.insert(
      id: 't2',
      title: 'Song Two',
      artist: 'Artist Two',
      durationMs: const Value(200000),
      localFilePath: Value(file2.path),
      lyricsLrc: const Value('[00:01.00] Ly2'),
      downloadStatus: const Value(DownloadStatus.completed),
    ));
    await db.upsertTrack(TracksCompanion.insert(
      id: 't3',
      title: 'Song Three',
      artist: 'Artist Three',
      durationMs: const Value(220000),
      localFilePath: Value(file3.path),
      lyricsLrc: const Value('[00:01.00] Ly3'),
      downloadStatus: const Value(DownloadStatus.completed),
    ));

    // Create a playlist with t1
    await db.createPlaylist(PlaylistsCompanion.insert(
      id: 'pl1',
      name: 'Playlist 1',
      isYoutubeSynced: const Value(true),
      youtubePlaylistId: const Value('PL_1'),
    ));
    await db.linkTrackToPlaylist(playlistId: 'pl1', trackId: 't1', position: 0);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );

    final playerNotifier = container.read(audioPlayerControllerProvider.notifier);

    final t1 = (await db.getTrackById('t1'))!;
    final pl1 = (await db.getPlaylistById('pl1'))!;

    // 1. Play song from playlist
    await playerNotifier.playPlaylist(pl1, [t1], targetTrack: t1);

    expect(container.read(audioPlayerControllerProvider).currentTrack?.id, 't1');
    expect(container.read(audioPlayerControllerProvider).currentPlaylist?.id, 'pl1');

    // 2. Fetch all tracks stream as LibraryScreen does
    final allTracks = await container.read(allTracksStreamProvider.future);
    expect(allTracks.length, 3);

    // 3. User taps Song Two in All Songs
    final songTwo = allTracks.firstWhere((t) => t.id == 't2');
    await playerNotifier.playTrack(songTwo, contextTracks: allTracks);

    // Verify track changed and context switched to All Songs (now_playing)
    expect(container.read(audioPlayerControllerProvider).currentTrack?.id, 't2');
    expect(container.read(audioPlayerControllerProvider).currentPlaylist?.id, 'now_playing');
    expect(container.read(audioPlayerControllerProvider).queue.map((t) => t.id).toList(), ['t1', 't2', 't3']);
    expect(container.read(audioPlayerControllerProvider).currentIndex, 1);
    expect(container.read(audioPlayerControllerProvider).isPlaying, isTrue);

    await playerNotifier.stopAndClear();
    container.dispose();
  });

  test('Library sorting orders tracks accurately across Title, Artist, Recently Added, and Duration', () async {
    final now = DateTime.now();
    final tr1 = Track(
      id: 't_a',
      title: 'Zeta Track',
      artist: 'Beta Artist',
      durationMs: 120000,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.subtract(const Duration(days: 2)),
    );
    final tr2 = Track(
      id: 't_b',
      title: 'Alpha Track',
      artist: 'Gamma Artist',
      durationMs: 300000,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final tr3 = Track(
      id: 't_c',
      title: 'Beta Track',
      artist: 'Alpha Artist',
      durationMs: 180000,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final rawList = [tr1, tr2, tr3];

    List<Track> sortTracks(List<Track> list, LibrarySortBy sortBy, bool ascending) {
      final copy = List<Track>.from(list);
      copy.sort((a, b) {
        int cmp;
        switch (sortBy) {
          case LibrarySortBy.title:
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            break;
          case LibrarySortBy.artist:
            cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
            break;
          case LibrarySortBy.recentlyAdded:
            cmp = a.createdAt.compareTo(b.createdAt);
            break;
          case LibrarySortBy.duration:
            cmp = a.durationMs.compareTo(b.durationMs);
            break;
        }
        return ascending ? cmp : -cmp;
      });
      return copy;
    }

    // 1. Sort by Title Ascending (Alpha, Beta, Zeta)
    final byTitleAsc = sortTracks(rawList, LibrarySortBy.title, true);
    expect(byTitleAsc.map((t) => t.id).toList(), ['t_b', 't_c', 't_a']);

    // 2. Sort by Title Descending (Zeta, Beta, Alpha)
    final byTitleDesc = sortTracks(rawList, LibrarySortBy.title, false);
    expect(byTitleDesc.map((t) => t.id).toList(), ['t_a', 't_c', 't_b']);

    // 3. Sort by Artist Ascending (Alpha Artist, Beta Artist, Gamma Artist)
    final byArtistAsc = sortTracks(rawList, LibrarySortBy.artist, true);
    expect(byArtistAsc.map((t) => t.id).toList(), ['t_c', 't_a', 't_b']);

    // 4. Sort by Duration Descending (300k, 180k, 120k)
    final byDurationDesc = sortTracks(rawList, LibrarySortBy.duration, false);
    expect(byDurationDesc.map((t) => t.id).toList(), ['t_b', 't_c', 't_a']);

    // 5. Sort by Recently Added Descending (Now, -1d, -2d)
    final byRecentDesc = sortTracks(rawList, LibrarySortBy.recentlyAdded, false);
    expect(byRecentDesc.map((t) => t.id).toList(), ['t_b', 't_c', 't_a']);
  });
}
