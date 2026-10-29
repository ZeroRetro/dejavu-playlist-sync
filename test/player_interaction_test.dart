import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:dejavu_music_player/core/database/app_database.dart';
import 'package:dejavu_music_player/features/player/audio_player_controller.dart';

class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  final _dataController = StreamController<PlayerDataMessage>.broadcast();
  final List<SeekRequest> seekRequests = [];
  int? _currentIndex;
  bool _playing = false;
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;

  FakeAudioPlayerPlatform(super.id);

  void setProcessingState(ProcessingStateMessage state) {
    _processingState = state;
    _broadcast();
  }

  void simulateAutoAdvance(int newIndex) {
    _currentIndex = newIndex;
    _broadcast();
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _eventController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataController.stream;

  void _broadcast() {
    _eventController.add(PlaybackEventMessage(
      processingState: _processingState,
      updatePosition: Duration.zero,
      updateTime: DateTime.now(),
      bufferedPosition: Duration.zero,
      duration: const Duration(minutes: 3),
      icyMetadata: null,
      currentIndex: _currentIndex,
      androidAudioSessionId: null,
    ));
    _dataController.add(PlayerDataMessage(
      playing: _playing,
      volume: 1.0,
      speed: 1.0,
      pitch: 1.0,
      loopMode: LoopModeMessage.off,
      shuffleMode: ShuffleModeMessage.none,
    ));
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _processingState = ProcessingStateMessage.ready;
    _currentIndex = request.initialIndex ?? 0;
    _broadcast();
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    _broadcast();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _broadcast();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seekRequests.add(request);
    if (request.index != null) {
      _currentIndex = request.index;
    }
    _broadcast();
    return SeekResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
      SetAndroidAudioAttributesRequest request) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
      SetShuffleOrderRequest request) async =>
      SetShuffleOrderResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _eventController.close();
    await _dataController.close();
    return DisposeResponse();
  }
}

class FakeJustAudioPlatform extends JustAudioPlatform {
  final Map<String, FakeAudioPlayerPlatform> players = {};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayerPlatform(request.id);
    players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File file1;
  late File file2;
  late File file3;

  setUpAll(() {
    JustAudioPlatform.instance = FakeJustAudioPlatform();

    tempDir = Directory.systemTemp.createTempSync('dejavu_test_');
    final dummyBytes = List<int>.filled(60 * 1024, 0);
    file1 = File('${tempDir.path}/track1.m4a')..writeAsBytesSync(dummyBytes);
    file2 = File('${tempDir.path}/track2.m4a')..writeAsBytesSync(dummyBytes);
    file3 = File('${tempDir.path}/track3.m4a')..writeAsBytesSync(dummyBytes);
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  test('Simulate: Play playlist, then click a song in All Songs tab', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );
    final t3 = Track(
      id: 't3',
      title: 'Song 3',
      artist: 'Artist 3',
      durationMs: 220000,
      localFilePath: file3.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final playlist = Playlist(
      id: 'pl_rock',
      name: 'Genre Playlist A',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. Play Playlist (contains t1 and t2)
    await controller.playPlaylist(playlist, [t1, t2], targetTrack: t1);

    expect(controller.state.currentTrack?.id, 't1');
    expect(controller.state.currentPlaylist?.id, 'pl_rock');
    expect(controller.state.queue.map((t) => t.id).toList(), ['t1', 't2']);

    // 2. Now simulate user navigating to All Songs tab.
    // In All Songs tab, the contextTracks is all tracks in the database [t3, t2, t1].
    final allSongsList = [t3, t2, t1];

    // User taps on t2 in All Songs
    await controller.playTrack(t2, contextTracks: allSongsList);

    expect(controller.state.currentTrack?.id, 't2');
    expect(controller.state.currentPlaylist?.id, 'now_playing');
    expect(controller.state.queue.map((t) => t.id).toList(), ['t3', 't2', 't1']);
    expect(controller.state.currentIndex, 1);

    controller.dispose();
  });

  test('Single playlist scenario: Library has same tracks as playlist', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final playlist = Playlist(
      id: 'pl_rock',
      name: 'Genre Playlist A',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. Play Playlist (contains t1 and t2)
    await controller.playPlaylist(playlist, [t1, t2], targetTrack: t1);
    expect(controller.state.currentTrack?.id, 't1');
    expect(controller.state.currentPlaylist?.id, 'pl_rock');

    // 2. Navigate to All Songs tab.
    // All Songs list is [t1, t2].
    // Note: state.queue has length 2 and first.id == 't1'.
    // User taps t2 in All Songs.
    await controller.playTrack(t2, contextTracks: [t1, t2]);

    // Expected: context should now be 'now_playing' (All Songs), track should be t2
    expect(controller.state.currentTrack?.id, 't2');
    expect(controller.state.currentPlaylist?.id, 'now_playing',
        reason: 'Context must switch from pl_rock to now_playing (All Songs)');

    controller.dispose();
  });

  test('User taps the currently playing song in All Songs tab', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final playlist = Playlist(
      id: 'pl_rock',
      name: 'Genre Playlist A',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. Play Playlist (t1 is playing)
    await controller.playPlaylist(playlist, [t1, t2], targetTrack: t1);
    expect(controller.state.currentTrack?.id, 't1');
    expect(controller.state.currentPlaylist?.id, 'pl_rock');

    // 2. User goes to All Songs tab and taps t1 (which was playing from pl_rock)
    await controller.playTrack(t1, contextTracks: [t1, t2]);

    expect(controller.state.currentTrack?.id, 't1');
    expect(controller.state.currentPlaylist?.id, 'now_playing',
        reason: 'Context must switch to now_playing');
    expect(controller.state.isPlaying, isTrue);

    controller.dispose();
  });

  test('User shuffles playlist, then clicks song in All Songs tab', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );
    final t3 = Track(
      id: 't3',
      title: 'Song 3',
      artist: 'Artist 3',
      durationMs: 220000,
      localFilePath: file3.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final playlist = Playlist(
      id: 'pl_rock',
      name: 'Genre Playlist A',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. User clicked "Shuffle" in PlaylistDetailScreen:
    // This shuffled downloadedTracks: [t3, t1, t2]
    await controller.playPlaylist(playlist, [t3, t1, t2], initialIndex: 0);
    expect(controller.state.currentTrack?.id, 't3');
    expect(controller.state.queue.map((t) => t.id).toList(), ['t3', 't1', 't2']);

    // 2. User goes to All Songs tab. Library order is [t1, t2, t3].
    // User taps t2 in All Songs.
    await controller.playTrack(t2, contextTracks: [t1, t2, t3]);

    expect(controller.state.currentTrack?.id, 't2');
    expect(controller.state.currentPlaylist?.id, 'now_playing');
    expect(controller.state.queue.map((t) => t.id).toList(), ['t1', 't2', 't3']);
    expect(controller.state.currentIndex, 1);

    controller.dispose();
  });

  test('Fast in-memory seek when already in All Songs context', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );
    final t3 = Track(
      id: 't3',
      title: 'Song 3',
      artist: 'Artist 3',
      durationMs: 220000,
      localFilePath: file3.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final controller = AudioPlayerController();

    // 1. Play t1 from All Songs
    await controller.playTrack(t1, contextTracks: [t1, t2, t3]);
    expect(controller.state.currentTrack?.id, 't1');
    expect(controller.state.currentPlaylist?.id, 'now_playing');
    expect(controller.state.currentIndex, 0);

    // 2. Play t3 from All Songs (should fast-path seek within same context)
    await controller.playTrack(t3, contextTracks: [t1, t2, t3]);
    expect(controller.state.currentTrack?.id, 't3');
    expect(controller.state.currentPlaylist?.id, 'now_playing');
    expect(controller.state.currentIndex, 2);

    controller.dispose();
  });

  test('Switch from All Songs back to a Playlist', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final playlist = Playlist(
      id: 'pl_jazz',
      name: 'Genre Playlist B',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. Play from All Songs
    await controller.playTrack(t1, contextTracks: [t1, t2]);
    expect(controller.state.currentPlaylist?.id, 'now_playing');

    // 2. Play playlist
    await controller.playPlaylist(playlist, [t2], targetTrack: t2);
    expect(controller.state.currentTrack?.id, 't2');
    expect(controller.state.currentPlaylist?.id, 'pl_jazz');
    expect(controller.state.queue.length, 1);

    controller.dispose();
  });

  test('Queue sheet track tap preserves current playlist context', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't2',
      title: 'Song 2',
      artist: 'Artist 2',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final playlist = Playlist(
      id: 'pl_metal',
      name: 'Genre Playlist C',
      isYoutubeSynced: true,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // 1. Play playlist
    await controller.playPlaylist(playlist, [t1, t2], targetTrack: t1);
    expect(controller.state.currentPlaylist?.id, 'pl_metal');

    // 2. Tap t2 from queue sheet (passes playlist: controller.state.currentPlaylist)
    await controller.playTrack(
      t2,
      contextTracks: controller.state.queue,
      playlist: controller.state.currentPlaylist,
    );

    expect(controller.state.currentTrack?.id, 't2');
    expect(controller.state.currentPlaylist?.id, 'pl_metal',
        reason: 'Tapping within queue sheet must preserve current playlist context');

    controller.dispose();
  });

  test('Mixed download statuses: Only completed tracks enter queue', () async {
    final now = DateTime.now();
    final completedTrack = Track(
      id: 't_done',
      title: 'Completed Song',
      artist: 'Artist',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final downloadingTrack = Track(
      id: 't_dl',
      title: 'Downloading Song',
      artist: 'Artist',
      durationMs: 200000,
      localFilePath: null,
      downloadStatus: DownloadStatus.downloading,
      createdAt: now,
    );
    final failedTrack = Track(
      id: 't_fail',
      title: 'Failed Song',
      artist: 'Artist',
      durationMs: 220000,
      localFilePath: null,
      downloadStatus: DownloadStatus.failed,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // Tap completed track from a list containing mixed statuses
    await controller.playTrack(
      completedTrack,
      contextTracks: [downloadingTrack, completedTrack, failedTrack],
    );

    expect(controller.state.currentTrack?.id, 't_done');
    expect(controller.state.queue.length, 1);
    expect(controller.state.queue.first.id, 't_done');
    expect(controller.state.currentIndex, 0);

    controller.dispose();
  });

  test('Change tracks while playing inside playlist (seamless in-place seek)', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 'track_a',
      title: 'Sample Track A',
      artist: 'Artist A',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 'track_b',
      title: 'Sample Track B',
      artist: 'Artist B',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final playlist = Playlist(
      id: 'pl_jazz',
      name: 'Genre Playlist D',
      isYoutubeSynced: false,
      createdAt: now,
    );

    final controller = AudioPlayerController();

    // Start playing Track A
    await controller.playTrack(t1, contextTracks: [t1, t2], playlist: playlist);
    expect(controller.state.currentTrack?.id, 'track_a');
    expect(controller.state.isPlaying, isTrue);

    // While actively playing, user taps Track B in the same playlist
    await controller.playTrack(t2, contextTracks: [t1, t2], playlist: playlist);
    expect(controller.state.currentTrack?.id, 'track_b');
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.currentIndex, 1);

    controller.dispose();
  });

  test('Change tracks while playing in All Songs tab', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 'track_x',
      title: 'Sample Track X',
      artist: 'Artist X',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 'track_y',
      title: 'Sample Track Y',
      artist: 'Artist Y',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final allSongsList = [t1, t2];
    final controller = AudioPlayerController();

    // Start Track X in All Songs
    await controller.playTrack(t1, contextTracks: allSongsList);
    expect(controller.state.currentTrack?.id, 'track_x');
    expect(controller.state.isPlaying, isTrue);

    // While actively playing, user taps Track Y in All Songs
    await controller.playTrack(t2, contextTracks: allSongsList);
    expect(controller.state.currentTrack?.id, 'track_y');
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.currentIndex, 1);

    controller.dispose();
  });

  test('Rapid Next / Prev invocations while playing do not lock player', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 't_one',
      title: 'Song 1',
      artist: 'Artist',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 't_two',
      title: 'Song 2',
      artist: 'Artist',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );
    final t3 = Track(
      id: 't_three',
      title: 'Song 3',
      artist: 'Artist',
      durationMs: 220000,
      localFilePath: file3.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final controller = AudioPlayerController();
    await controller.playPlaylist(
      Playlist(
        id: 'pl_multi',
        name: 'Multi',
        isYoutubeSynced: false,
        createdAt: now,
      ),
      [t1, t2, t3],
      initialIndex: 0,
    );

    // Rapidly invoke seekToNext several times without delays
    await Future.wait([
      controller.seekToNext(),
      controller.seekToNext(),
    ]);

    expect(controller.state.isPlaying, isTrue);

    controller.dispose();
  });

  test('Skip arrow (seekToNext / seekToPrevious) updates currentTrack, index, and metadata synchronously', () async {
    final now = DateTime.now();
    final t1 = Track(
      id: 'song_a',
      title: 'First Song',
      artist: 'Artist A',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 'song_b',
      title: 'Second Song',
      artist: 'Artist B',
      durationMs: 200000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );
    final t3 = Track(
      id: 'song_c',
      title: 'Third Song',
      artist: 'Artist C',
      durationMs: 220000,
      localFilePath: file3.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 2)),
    );

    final controller = AudioPlayerController();
    await controller.playPlaylist(
      Playlist(
        id: 'pl_sync_test',
        name: 'Sync Test',
        isYoutubeSynced: false,
        createdAt: now,
      ),
      [t1, t2, t3],
      initialIndex: 0,
    );

    // Initial state check
    expect(controller.state.currentTrack?.id, 'song_a');
    expect(controller.state.currentTrack?.title, 'First Song');
    expect(controller.state.currentIndex, 0);

    // 1. User clicks Next Arrow (seekToNext)
    await controller.seekToNext();
    expect(controller.state.currentTrack?.id, 'song_b');
    expect(controller.state.currentTrack?.title, 'Second Song');
    expect(controller.state.currentIndex, 1);
    expect(controller.state.position, Duration.zero);

    // 2. User clicks Next Arrow again (seekToNext -> song_c)
    await controller.seekToNext();
    expect(controller.state.currentTrack?.id, 'song_c');
    expect(controller.state.currentTrack?.title, 'Third Song');
    expect(controller.state.currentIndex, 2);

    // 3. User clicks Previous Arrow within 3 seconds (seekToPrevious -> song_b)
    await controller.seekToPrevious();
    expect(controller.state.currentTrack?.id, 'song_b');
    expect(controller.state.currentTrack?.title, 'Second Song');
    expect(controller.state.currentIndex, 1);

    controller.dispose();
  });

  test('Stall watchdog automatically nudges AudioTrack when playback stalls at 0:00', () async {
    final controller = AudioPlayerController();
    final now = DateTime.now();
    final t1 = Track(
      id: 'song_w1',
      title: 'Track 1',
      artist: 'Artist 1',
      durationMs: 180000,
      localFilePath: file1.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 'song_w2',
      title: 'Track 2',
      artist: 'Artist 2',
      durationMs: 180000,
      localFilePath: file2.path,
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    await controller.playPlaylist(
      Playlist(
        id: 'pl_watchdog',
        name: 'Watchdog Playlist',
        isYoutubeSynced: false,
        createdAt: now,
      ),
      [t1, t2],
      initialIndex: 0,
    );

    final playerPlatform =
        (JustAudioPlatform.instance as FakeJustAudioPlatform).players.values.last;
    playerPlatform.seekRequests.clear();

    // Skip to next track
    await controller.seekToNext();
    expect(controller.state.currentTrack?.id, 'song_w2');
    expect(controller.state.isPlaying, true);

    // Initial seek requested 0:00
    expect(playerPlatform.seekRequests.last.position, Duration.zero);

    // Simulate an audio sink stall at 0:00 (ExoPlayer drops into buffering)
    playerPlatform.setProcessingState(ProcessingStateMessage.buffering);

    // Wait for the stall watchdog (1200ms) while position stays at 0
    await Future.delayed(const Duration(milliseconds: 1350));

    // Watchdog detected position <= 20ms and auto-nudged with 50ms
    expect(
      playerPlatform.seekRequests
          .any((r) => r.position == const Duration(milliseconds: 50)),
      isTrue,
    );

    controller.dispose();
  });

  test('Natural auto-advance transition updates currentTrack, lyrics, and metadata synchronously', () async {
    final controller = AudioPlayerController();
    final now = DateTime.now();
    final t1 = Track(
      id: 'song_auto_1',
      title: 'First Auto Track',
      artist: 'First Artist',
      durationMs: 180000,
      localFilePath: file1.path,
      lyricsLrc: '[00:01.00] Lyrics for Song 1',
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final t2 = Track(
      id: 'song_auto_2',
      title: 'Second Auto Track',
      artist: 'Second Artist',
      durationMs: 210000,
      localFilePath: file2.path,
      lyricsLrc: '[00:01.00] Lyrics for Song 2',
      downloadStatus: DownloadStatus.completed,
      createdAt: now.add(const Duration(seconds: 1)),
    );

    await controller.playPlaylist(
      Playlist(
        id: 'pl_auto',
        name: 'Auto Transition Playlist',
        isYoutubeSynced: false,
        createdAt: now,
      ),
      [t1, t2],
      initialIndex: 0,
    );

    expect(controller.state.currentIndex, 0);
    expect(controller.state.currentTrack?.id, 'song_auto_1');
    expect(controller.state.currentTrack?.title, 'First Auto Track');
    expect(controller.state.currentTrack?.lyricsLrc, '[00:01.00] Lyrics for Song 1');

    final playerPlatform =
        (JustAudioPlatform.instance as FakeJustAudioPlatform).players.values.last;

    // Simulate ExoPlayer advancing naturally to index 1 as song 1 ends
    playerPlatform.simulateAutoAdvance(1);

    // Yield to stream event dispatch
    await Future.delayed(const Duration(milliseconds: 50));

    // Verify metadata and lyrics updated immediately to Song 2
    expect(controller.state.currentIndex, 1);
    expect(controller.state.currentTrack?.id, 'song_auto_2');
    expect(controller.state.currentTrack?.title, 'Second Auto Track');
    expect(controller.state.currentTrack?.artist, 'Second Artist');
    expect(controller.state.currentTrack?.lyricsLrc, '[00:01.00] Lyrics for Song 2');
    expect(controller.state.duration.inMilliseconds, 210000);

    controller.dispose();
  });

  test('Playing song from Playlist A and then playing song from Playlist B updates context, queue, and metadata atomically without desync', () async {
    final controller = AudioPlayerController();
    final now = DateTime.now();

    final trackA1 = Track(
      id: 't_a1',
      title: 'Track A1',
      artist: 'Artist Alpha',
      durationMs: 180000,
      localFilePath: file1.path,
      lyricsLrc: '[00:01.00] Lyrics Alpha 1',
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final trackA2 = Track(
      id: 't_a2',
      title: 'Track A2',
      artist: 'Artist Alpha',
      durationMs: 200000,
      localFilePath: file2.path,
      lyricsLrc: '[00:01.00] Lyrics Alpha 2',
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );

    final trackB1 = Track(
      id: 't_b1',
      title: 'Track B1',
      artist: 'Artist Beta',
      durationMs: 220000,
      localFilePath: file2.path,
      lyricsLrc: '[00:01.00] Lyrics Beta 1',
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );
    final trackB2 = Track(
      id: 't_b2',
      title: 'Track B2',
      artist: 'Artist Beta',
      durationMs: 240000,
      localFilePath: file3.path,
      lyricsLrc: '[00:01.00] Lyrics Beta 2',
      downloadStatus: DownloadStatus.completed,
      createdAt: now,
    );

    final playlistA = Playlist(
      id: 'pl_alpha',
      name: 'Alpha Playlist',
      isYoutubeSynced: false,
      createdAt: now,
    );

    final playlistB = Playlist(
      id: 'pl_beta',
      name: 'Beta Playlist',
      isYoutubeSynced: false,
      createdAt: now,
    );

    // 1. Start playing Track A1 from Playlist A
    await controller.playTrack(
      trackA1,
      contextTracks: [trackA1, trackA2],
      playlist: playlistA,
    );

    expect(controller.state.currentPlaylist?.id, 'pl_alpha');
    expect(controller.state.currentTrack?.id, 't_a1');
    expect(controller.state.currentTrack?.title, 'Track A1');
    expect(controller.state.currentIndex, 0);
    expect(controller.state.queue.map((t) => t.id).toList(), ['t_a1', 't_a2']);

    // 2. While playing, user taps Track B2 in Playlist B
    await controller.playTrack(
      trackB2,
      contextTracks: [trackB1, trackB2],
      playlist: playlistB,
    );

    // 3. Verify that Playlist B's context, queue, and Track B2 metadata are immediately active
    expect(controller.state.currentPlaylist?.id, 'pl_beta');
    expect(controller.state.currentPlaylist?.name, 'Beta Playlist');
    expect(controller.state.currentTrack?.id, 't_b2');
    expect(controller.state.currentTrack?.title, 'Track B2');
    expect(controller.state.currentTrack?.artist, 'Artist Beta');
    expect(controller.state.currentTrack?.lyricsLrc, '[00:01.00] Lyrics Beta 2');
    expect(controller.state.currentIndex, 1);
    expect(controller.state.queue.map((t) => t.id).toList(), ['t_b1', 't_b2']);
    expect(controller.state.isPlaying, isTrue);

    controller.dispose();
  });
}
