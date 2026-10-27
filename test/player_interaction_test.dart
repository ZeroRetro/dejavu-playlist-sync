import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:dejavu_music_player/core/database/app_database.dart';
import 'package:dejavu_music_player/features/player/audio_player_controller.dart';

class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  final _dataController = StreamController<PlayerDataMessage>.broadcast();
  int? _currentIndex;
  bool _playing = false;
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;

  FakeAudioPlayerPlatform(super.id);

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
      name: 'Rock Classics',
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
      name: 'Rock Classics',
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
      name: 'Rock Classics',
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
      name: 'Rock Classics',
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
      name: 'Smooth Jazz',
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
      name: 'Heavy Metal',
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
}
