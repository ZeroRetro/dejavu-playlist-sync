import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:dejavu_music_player/core/database/app_database.dart';
import 'package:dejavu_music_player/core/utils/duration_formatter.dart';
import 'package:dejavu_music_player/core/utils/file_utils.dart';
import 'package:dejavu_music_player/core/utils/lrc_parser.dart';
import 'package:dejavu_music_player/features/sync_engine/youtube_sync_service.dart';
import 'package:dejavu_music_player/features/player/audio_player_controller.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

void main() {
  group('DurationFormatter Tests', () {
    test('formats milliseconds properly', () {
      expect(DurationFormatter.formatMs(0), '00:00');
      expect(DurationFormatter.formatMs(65000), '01:05');
      expect(DurationFormatter.formatMs(252000), '04:12');
      expect(DurationFormatter.formatMs(3665000), '1:01:05');
    });

    test('formats human-readable duration properly', () {
      expect(DurationFormatter.formatHumanMs(0), '');
      expect(DurationFormatter.formatHumanMs(45000), '45 sec');
      expect(DurationFormatter.formatHumanMs(120000), '2 min');
      expect(DurationFormatter.formatHumanMs(3720000), '1 hr 2 min');
      expect(DurationFormatter.formatHumanMs(7200000), '2 hr');
    });
  });

  group('FileUtils Tests', () {
    test('sanitizes illegal filename characters', () {
      expect(FileUtils.sanitizeFilename('Rock/Metal: Heavy*Hits?'),
          'Rock_Metal_ Heavy_Hits_');
      expect(FileUtils.sanitizeFilename('   Normal Playlist   '),
          'Normal Playlist');
      expect(FileUtils.sanitizeFilename(':::'), 'playlist');
      expect(FileUtils.sanitizeFilename('CON'), '_CON');
      expect(FileUtils.sanitizeFilename('aux'), '_aux');
      expect(FileUtils.sanitizeFilename('NUL.m3u8'), 'NUL.m3u8');
      expect(FileUtils.sanitizeFilename('Trailing dots....'), 'Trailing dots');
    });

    test('generates valid RFC 8216 M3U8 content', () {
      final now = DateTime.now();
      final tracks = [
        Track(
          id: 't1',
          title: 'Big Buck Bunny Suite',
          artist: 'Blender Foundation',
          durationMs: 432000,
          localFilePath: '/storage/emulated/0/dejavu_audio/t1.m4a',
          downloadStatus: DownloadStatus.completed,
          createdAt: now,
        ),
        Track(
          id: 't2',
          title: 'Sintel Theme',
          artist: 'Jan Morgenstern',
          durationMs: 253000,
          localFilePath: '/storage/emulated/0/dejavu_audio/t2.m4a',
          downloadStatus: DownloadStatus.completed,
          createdAt: now,
        ),
      ];

      final m3u8 = FileUtils.generateM3U8Content(
        playlistName: 'Open Media Archive',
        tracks: tracks,
        baseDirectoryPath: '/storage/emulated/0/dejavu_audio',
      );

      expect(m3u8, contains('#EXTM3U'));
      expect(m3u8, contains('#PLAYLIST:Open Media Archive'));
      expect(m3u8,
          contains('#EXTINF:432,Blender Foundation - Big Buck Bunny Suite'));
      expect(m3u8, contains('t1.m4a'));
      expect(m3u8, contains('#EXTINF:253,Jan Morgenstern - Sintel Theme'));
      expect(m3u8, contains('t2.m4a'));
    });

    test('cleans title and artist strings properly', () {
      final res1 = YoutubeSyncService.cleanTitleAndArtist(
        rawTitle: 'Synthetic Odyssey (Official Music Video) [4K Remaster]',
        rawAuthor: 'Open Audio Lab - Topic',
      );
      expect(res1.title, 'Synthetic Odyssey');
      expect(res1.artist, 'Open Audio Lab');

      final res2 = YoutubeSyncService.cleanTitleAndArtist(
        rawTitle: 'Creative Artist - Ambient Soundscapes (Lyrics)',
        rawAuthor: 'Vevo Records',
      );
      expect(res2.title, 'Ambient Soundscapes');
      expect(res2.artist, 'Creative Artist');
    });
  });

  group('PlaylistSyncState Tests', () {
    test('computes progress accurately', () {
      const state0 = PlaylistSyncState(
        playlistId: 'test_1',
        totalToDownload: 0,
        completedDownloads: 0,
      );
      expect(state0.progress, 0.0);

      const state1 = PlaylistSyncState(
        playlistId: 'test_1',
        totalToDownload: 10,
        completedDownloads: 5,
      );
      expect(state1.progress, 0.5);

      final stateUpdated = state1.copyWith(completedDownloads: 10);
      expect(stateUpdated.progress, 1.0);

      // Sub-track progress computation
      final stateWithSubTrack = state1.copyWith(
        completedDownloads: 1,
        trackProgress: 0.5,
        trackBytesReceived: 5 * 1024 * 1024,
        trackBytesTotal: 10 * 1024 * 1024,
        downloadSpeedKbps: 4500.0,
      );
      // (1 + 0.5) / 10 = 0.15
      expect(stateWithSubTrack.progress, 0.15);
      expect(stateWithSubTrack.trackBytesReceived, 5 * 1024 * 1024);
      expect(stateWithSubTrack.downloadSpeedKbps, 4500.0);
    });

    test('manages sync stages, metadata, and indeterminate states properly',
        () {
      const stateFetching = PlaylistSyncState(
        playlistId: 'test_pl',
        isSyncing: true,
        stage: SyncStage.fetchingMetadata,
        statusMessage: 'Connecting to YouTube...',
      );
      expect(stateFetching.isIndeterminate, isTrue);
      expect(stateFetching.progress, 0.0);

      const stateAllUpToDate = PlaylistSyncState(
        playlistId: 'test_pl',
        isSyncing: true,
        stage: SyncStage.downloading,
        totalTracksInPlaylist: 25,
        totalToDownload: 0,
        completedDownloads: 0,
        statusMessage: 'All 25 tracks already downloaded and up to date',
      );
      expect(stateAllUpToDate.isIndeterminate, isTrue);
      expect(stateAllUpToDate.totalTracksInPlaylist, 25);
      expect(stateAllUpToDate.totalToDownload, 0);

      const stateActiveDownload = PlaylistSyncState(
        playlistId: 'test_pl',
        isSyncing: true,
        stage: SyncStage.downloading,
        totalTracksInPlaylist: 25,
        totalToDownload: 4,
        completedDownloads: 2,
        currentTrackTitle: 'Awesome Track',
      );
      expect(stateActiveDownload.isIndeterminate, isFalse);
      expect(stateActiveDownload.progress, 0.5);
    });
  });

  group('Playlist Deletion & Orphan Retention Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('deletePlaylist with deleteAudioFiles: false preserves all tracks',
        () async {
      const plId = 'pl_1';
      const trackId = 't_1';

      await db.createPlaylist(
        PlaylistsCompanion.insert(
          id: plId,
          name: 'Creative Commons Showcase',
          isYoutubeSynced: const Value(true),
          youtubePlaylistId: const Value('PL123'),
        ),
      );

      await db.upsertTrack(
        TracksCompanion.insert(
          id: trackId,
          title: 'Canon in D Major',
          artist: 'Johann Pachelbel',
          downloadStatus: const Value(DownloadStatus.completed),
        ),
      );

      await db.linkTrackToPlaylist(
        playlistId: plId,
        trackId: trackId,
        position: 0,
      );

      // Verify linked
      var plTracks = await db.getTracksInPlaylist(plId);
      expect(plTracks.length, 1);

      // Delete playlist without deleting audio files
      await db.deletePlaylist(plId, deleteAudioFiles: false);

      // Playlist is gone
      final pl = await db.getPlaylistById(plId);
      expect(pl, isNull);

      // Track remains in database (All Songs)
      final allTracks = await db.select(db.tracks).get();
      expect(allTracks.length, 1);
      expect(allTracks.first.id, trackId);
    });

    test(
        'deletePlaylist with deleteAudioFiles: true deletes unique tracks but preserves tracks used in other playlists',
        () async {
      const pl1 = 'pl_1';
      const pl2 = 'pl_2';
      const uniqueTrackId = 't_unique';
      const sharedTrackId = 't_shared';

      await db.createPlaylist(
        PlaylistsCompanion.insert(
          id: pl1,
          name: 'Playlist One',
          isYoutubeSynced: const Value(true),
          youtubePlaylistId: const Value('PL1'),
        ),
      );
      await db.createPlaylist(
        PlaylistsCompanion.insert(
          id: pl2,
          name: 'Playlist Two',
          isYoutubeSynced: const Value(true),
          youtubePlaylistId: const Value('PL2'),
        ),
      );

      await db.upsertTrack(
        TracksCompanion.insert(
          id: uniqueTrackId,
          title: 'Unique Track',
          artist: 'Artist A',
          downloadStatus: const Value(DownloadStatus.completed),
        ),
      );
      await db.upsertTrack(
        TracksCompanion.insert(
          id: sharedTrackId,
          title: 'Shared Track',
          artist: 'Artist B',
          downloadStatus: const Value(DownloadStatus.completed),
        ),
      );

      // Link uniqueTrack to pl1 only
      await db.linkTrackToPlaylist(
        playlistId: pl1,
        trackId: uniqueTrackId,
        position: 0,
      );

      // Link sharedTrack to BOTH pl1 and pl2
      await db.linkTrackToPlaylist(
        playlistId: pl1,
        trackId: sharedTrackId,
        position: 1,
      );
      await db.linkTrackToPlaylist(
        playlistId: pl2,
        trackId: sharedTrackId,
        position: 0,
      );

      // Delete pl1 with deleteAudioFiles: true
      await db.deletePlaylist(pl1, deleteAudioFiles: true);

      // pl1 is deleted
      expect(await db.getPlaylistById(pl1), isNull);

      // uniqueTrack should be purged from DB
      final uniqueTrack = await (db.select(db.tracks)
            ..where((t) => t.id.equals(uniqueTrackId)))
          .getSingleOrNull();
      expect(uniqueTrack, isNull);

      // sharedTrack MUST be preserved because pl2 still links it!
      final sharedTrack = await (db.select(db.tracks)
            ..where((t) => t.id.equals(sharedTrackId)))
          .getSingleOrNull();
      expect(sharedTrack, isNotNull);
      expect(sharedTrack!.id, sharedTrackId);

      // pl2 still has sharedTrack
      final pl2Tracks = await db.getTracksInPlaylist(pl2);
      expect(pl2Tracks.length, 1);
      expect(pl2Tracks.first.id, sharedTrackId);

      // Verify getAllPlaylists and getTrackById
      final allPlaylists = await db.getAllPlaylists();
      expect(allPlaylists.length, 1);
      expect(allPlaylists.first.id, pl2);

      final trackFound = await db.getTrackById(sharedTrackId);
      expect(trackFound, isNotNull);
      expect(trackFound!.title, 'Shared Track');

      final trackNotFound = await db.getTrackById('non_existent');
      expect(trackNotFound, isNull);
    });
  });

  group('PlayerStateSnapshot Tests', () {
    test('initial state has null currentTrack and empty queue', () {
      const snapshot = PlayerStateSnapshot();
      expect(snapshot.currentTrack, isNull);
      expect(snapshot.currentPlaylist, isNull);
      expect(snapshot.queue, isEmpty);
      expect(snapshot.isPlaying, isFalse);
    });

    test('copyWith updates fields and allows clearing track', () {
      final now = DateTime.now();
      final track = Track(
        id: 'test_track',
        title: 'Title',
        artist: 'Artist',
        durationMs: 180000,
        downloadStatus: DownloadStatus.completed,
        createdAt: now,
      );
      final pl = Playlist(
        id: 'pl1',
        name: 'My Playlist',
        isYoutubeSynced: true,
        createdAt: now,
      );

      var snapshot = const PlayerStateSnapshot().copyWith(
        currentTrack: () => track,
        currentPlaylist: () => pl,
        isPlaying: true,
      );

      expect(snapshot.currentTrack?.id, 'test_track');
      expect(snapshot.currentPlaylist?.id, 'pl1');
      expect(snapshot.isPlaying, isTrue);

      // Clearing back to null
      snapshot = snapshot.copyWith(
        currentTrack: () => null,
        currentPlaylist: () => null,
        isPlaying: false,
      );

      expect(snapshot.currentTrack, isNull);
      expect(snapshot.currentPlaylist, isNull);
      expect(snapshot.isPlaying, isFalse);
    });

    test('parses playlist ID with &si= query params', () {
      const url =
          'https://music.youtube.com/playlist?list=PLCC_TEST_ARCHIVE_123456789&si=qUXfN_NWpC0N1xgC';
      final id = yt.PlaylistId.parsePlaylistId(url);
      expect(id, 'PLCC_TEST_ARCHIVE_123456789');
    });

    test('StreamProviders are defined and accessible', () {
      expect(playlistsWithCountsStreamProvider, isNotNull);
      expect(allTracksStreamProvider, isNotNull);
      expect(playlistTracksStreamProvider, isNotNull);
    });
  });

  group('LrcParser Tests', () {
    test('parses standard [mm:ss.xx] and [mm:ss.xxx] timestamps', () {
      const lrc = '''
[ti:Sample Track]
[ar:Creative Commons Artist]
[00:04.20]First line of lyrics
[00:12.850]Second line with millisecond precision
[01:05.00]Chorus starts here
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, 3);
      expect(lines[0].timestamp, const Duration(seconds: 4, milliseconds: 200));
      expect(lines[0].text, 'First line of lyrics');
      expect(
          lines[1].timestamp, const Duration(seconds: 12, milliseconds: 850));
      expect(lines[1].text, 'Second line with millisecond precision');
      expect(lines[2].timestamp, const Duration(minutes: 1, seconds: 5));
      expect(lines[2].text, 'Chorus starts here');
    });

    test('sorts lines chronologically if received out of order', () {
      const lrc = '''
[00:30.00]Line two
[00:10.00]Line one
[01:00.00]Line three
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, 3);
      expect(lines[0].text, 'Line one');
      expect(lines[1].text, 'Line two');
      expect(lines[2].text, 'Line three');
    });

    test('handles empty or malformed LRC cleanly', () {
      expect(LrcParser.parse(''), isEmpty);
      expect(LrcParser.parse('No timestamps at all here\nJust text'), isEmpty);
      expect(LrcParser.parse(null), isEmpty);
    });

    test('findActiveIndex finds the correct line for current position', () {
      const lrc = '''
[00:10.00]First line
[00:20.00]Second line
[00:30.00]Third line
''';
      final lines = LrcParser.parse(lrc);

      // Before first line
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 5)), -1);

      // Exactly at first line
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 10)), 0);

      // Between first and second line
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 15)), 0);

      // Exactly at second line
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 20)), 1);

      // Far past last line
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 50)), 2);
    });
  });
}
