import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../core/database/app_database.dart';

class PlayerStateSnapshot {
  final Track? currentTrack;
  final Playlist? currentPlaylist;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final bool isShuffleEnabled;
  final LoopMode loopMode;

  const PlayerStateSnapshot({
    this.currentTrack,
    this.currentPlaylist,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffleEnabled = false,
    this.loopMode = LoopMode.off,
  });

  PlayerStateSnapshot copyWith({
    Track? Function()? currentTrack,
    Playlist? Function()? currentPlaylist,
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    bool? isShuffleEnabled,
    LoopMode? loopMode,
  }) {
    return PlayerStateSnapshot(
      currentTrack:
          currentTrack != null ? currentTrack() : this.currentTrack,
      currentPlaylist: currentPlaylist != null
          ? currentPlaylist()
          : this.currentPlaylist,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

class AudioPlayerController extends StateNotifier<PlayerStateSnapshot> {
  final AudioPlayer _player;
  ConcatenatingAudioSource? _playlistSource;
  final List<StreamSubscription> _subscriptions = [];

  AudioPlayerController()
      : _player = AudioPlayer(
          handleInterruptions: true,
          androidApplyAudioAttributes: true,
          handleAudioSessionActivation: true,
        ),
        super(const PlayerStateSnapshot()) {
    _initListeners();
  }

  void _initListeners() {
    _subscriptions.add(_player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      final isBuffering = processingState == ProcessingState.buffering ||
          processingState == ProcessingState.loading;

      if (state.currentTrack != null) {
        state = state.copyWith(
          isPlaying: isPlaying,
          isBuffering: isBuffering,
        );
      }
    }));

    _subscriptions.add(_player.positionStream.listen((pos) {
      if (state.currentTrack != null) {
        state = state.copyWith(position: pos);
      }
    }));

    _subscriptions.add(_player.durationStream.listen((dur) {
      if (dur != null && state.currentTrack != null) {
        state = state.copyWith(duration: dur);
      }
    }));

    _subscriptions.add(_player.currentIndexStream.listen((index) {
      if (state.currentTrack != null &&
          index != null &&
          index >= 0 &&
          index < state.queue.length) {
        final track = state.queue[index];
        state = state.copyWith(
          currentIndex: index,
          currentTrack: () => track,
          duration: Duration(milliseconds: track.durationMs),
        );
      }
    }));

    _subscriptions.add(_player.shuffleModeEnabledStream.listen((enabled) {
      state = state.copyWith(isShuffleEnabled: enabled);
    }));

    _subscriptions.add(_player.loopModeStream.listen((loop) {
      state = state.copyWith(loopMode: loop);
    }));

    _subscriptions.add(_player.playbackEventStream.listen(
      (event) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('AudioPlayer error: $error');
        stopAndClear();
      },
    ));
  }

  /// Play an entire playlist (gapless playback with ConcatenatingAudioSource)
  Future<void> playPlaylist(
    Playlist playlist,
    List<Track> tracks, {
    int initialIndex = 0,
  }) async {
    final playableTracks = tracks
        .where((t) =>
            t.localFilePath != null && File(t.localFilePath!).existsSync())
        .toList();

    if (playableTracks.isEmpty) {
      return;
    }

    final audioSources = <AudioSource>[];
    for (final track in playableTracks) {
      Uri? artUri;
      if (track.thumbnailPath != null) {
        final thumbFile = File(track.thumbnailPath!);
        if (thumbFile.existsSync()) {
          artUri = Uri.file(thumbFile.path);
        }
      }

      final mediaItem = MediaItem(
        id: track.id,
        album: playlist.name,
        title: track.title,
        artist: track.artist,
        duration: Duration(milliseconds: track.durationMs),
        artUri: artUri,
      );

      audioSources.add(
        AudioSource.file(
          track.localFilePath!,
          tag: mediaItem,
        ),
      );
    }

    _playlistSource = ConcatenatingAudioSource(
      children: audioSources,
      useLazyPreparation: false,
    );

    state = state.copyWith(
      currentPlaylist: () => playlist,
      queue: playableTracks,
      currentIndex: initialIndex.clamp(0, playableTracks.length - 1),
      currentTrack: () => playableTracks[
          initialIndex.clamp(0, playableTracks.length - 1)],
    );

    try {
      // Guard against DAC discontinuity/popping: pause active AudioTrack before tearing down decoder
      if (_player.playing) {
        await _player.pause();
      }

      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: initialIndex.clamp(0, playableTracks.length - 1),
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    }
  }

  bool _isChangingTrack = false;

  /// Play a single track directly
  Future<void> playTrack(Track track, {List<Track>? contextTracks}) async {
    if (_isChangingTrack) return;
    _isChangingTrack = true;
    try {
      final tracks = contextTracks ?? [track];
      final targetIndex = tracks.indexWhere((t) => t.id == track.id);

      // Fast-path: if this exact playlist queue is already initialized and loaded,
      // avoid rebuilding ConcatenatingAudioSource and resetting ExoPlayer.
      // Perform a seamless in-memory seek to target index instead.
      if (_playlistSource != null &&
          state.queue.length == tracks.length &&
          targetIndex >= 0 &&
          targetIndex < state.queue.length &&
          state.queue[targetIndex].id == track.id) {
        try {
          await _player.seek(Duration.zero, index: targetIndex);
          if (!_player.playing) {
            await _player.play();
          }
          return;
        } catch (e) {
          debugPrint('Direct seek to track index failed, reloading: $e');
        }
      }

      final dummyPlaylist = Playlist(
        id: 'now_playing',
        name: 'Now Playing',
        isYoutubeSynced: false,
        createdAt: DateTime.now(),
      );

      await playPlaylist(
        dummyPlaylist,
        tracks,
        initialIndex: targetIndex >= 0 ? targetIndex : 0,
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 120));
      _isChangingTrack = false;
    }
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  /// Stop playback, unload current playlist/queue, and completely reset player state snapshot
  Future<void> stopAndClear() async {
    _playlistSource = null;
    state = const PlayerStateSnapshot();
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping player: $e');
    }
    state = const PlayerStateSnapshot();
  }

  Future<void> stop() => stopAndClear();

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekToNext() async {
    if (_isChangingTrack) return;
    _isChangingTrack = true;
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      }
    } catch (e) {
      debugPrint('Error seeking to next: $e');
    } finally {
      // Guard against rapid multi-tap popping by allowing the audio pipeline to stabilize
      await Future.delayed(const Duration(milliseconds: 120));
      _isChangingTrack = false;
    }
  }

  Future<void> seekToPrevious() async {
    if (_isChangingTrack) return;
    _isChangingTrack = true;
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    } catch (e) {
      debugPrint('Error seeking to previous: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 120));
      _isChangingTrack = false;
    }
  }

  Future<void> toggleShuffle() async {
    final enabled = !state.isShuffleEnabled;
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> toggleLoopMode() async {
    final current = state.loopMode;
    final next = current == LoopMode.off
        ? LoopMode.all
        : current == LoopMode.all
            ? LoopMode.one
            : LoopMode.off;
    await _player.setLoopMode(next);
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, PlayerStateSnapshot>((ref) {
  return AudioPlayerController();
});
