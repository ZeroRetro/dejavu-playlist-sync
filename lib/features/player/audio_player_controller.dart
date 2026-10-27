import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../core/database/app_database.dart';
import '../sync_engine/youtube_sync_service.dart';

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
  final Ref? _ref;
  ConcatenatingAudioSource? _playlistSource;
  final List<StreamSubscription> _subscriptions = [];
  bool _isLoadingSource = false;

  AudioPlayerController([this._ref])
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
      if (!_isLoadingSource &&
          state.currentTrack != null &&
          index != null &&
          index >= 0 &&
          index < state.queue.length) {
        final track = state.queue[index];
        state = state.copyWith(
          currentIndex: index,
          currentTrack: () => track,
          duration: Duration(milliseconds: track.durationMs),
        );
        _maybeFetchLyrics(track);
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

  /// Automatically fetches missing synchronized lyrics in background and updates DB
  void _maybeFetchLyrics(Track track) {
    if (track.lyricsLrc != null && track.lyricsLrc!.trim().isNotEmpty) return;
    Future.microtask(() async {
      try {
        final syncService = _ref?.read(youtubeSyncServiceProvider);
        final db = _ref?.read(appDatabaseProvider);
        if (syncService == null || db == null) return;
        final lyrics = await syncService.fetchLyricsForTrack(
          title: track.title,
          artist: track.artist,
          duration: Duration(milliseconds: track.durationMs),
          youtubeVideoId: track.youtubeVideoId,
        );
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          await (db.update(db.tracks)..where((t) => t.id.equals(track.id))).write(
            TracksCompanion(lyricsLrc: Value(lyrics)),
          );
          if (state.currentTrack?.id == track.id) {
            state = state.copyWith(
              currentTrack: () => track.copyWith(lyricsLrc: Value(lyrics)),
            );
          }
        }
      } catch (e) {
        debugPrint('Auto-fetch lyrics notice: $e');
      }
    });
  }

  /// Play an entire playlist (gapless playback with ConcatenatingAudioSource)
  Future<void> playPlaylist(
    Playlist playlist,
    List<Track> tracks, {
    int initialIndex = 0,
    Track? targetTrack,
  }) async {
    final playableTracks = tracks.where((t) {
      if (t.localFilePath == null) return false;
      try {
        final f = File(t.localFilePath!);
        return f.existsSync() && f.lengthSync() >= 50 * 1024;
      } catch (_) {
        return false;
      }
    }).toList();

    if (playableTracks.isEmpty) {
      return;
    }

    int safeIndex = 0;
    if (targetTrack != null) {
      final found = playableTracks.indexWhere((t) => t.id == targetTrack.id);
      if (found >= 0) {
        safeIndex = found;
      } else {
        safeIndex = initialIndex.clamp(0, playableTracks.length - 1);
      }
    } else {
      safeIndex = initialIndex.clamp(0, playableTracks.length - 1);
    }
    final actualTargetTrack = playableTracks[safeIndex];

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
      useLazyPreparation: true,
    );

    state = state.copyWith(
      currentPlaylist: () => playlist,
      queue: playableTracks,
      currentIndex: safeIndex,
      currentTrack: () => actualTargetTrack,
      position: Duration.zero,
      duration: Duration(milliseconds: actualTargetTrack.durationMs),
      isPlaying: true,
    );

    _maybeFetchLyrics(actualTargetTrack);

    _isLoadingSource = true;
    try {
      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    } finally {
      _isLoadingSource = false;
    }
  }

  bool _isChangingTrack = false;

  /// Play a single track directly
  Future<void> playTrack(
    Track track, {
    List<Track>? contextTracks,
    Playlist? playlist,
  }) async {
    if (_isChangingTrack) return;
    _isChangingTrack = true;
    try {
      if (track.localFilePath == null) return;
      try {
        final f = File(track.localFilePath!);
        if (!f.existsSync() || f.lengthSync() < 50 * 1024) {
          debugPrint('Audio file is missing or invalid (< 50KB): ${track.localFilePath}');
          return;
        }
      } catch (_) {
        return;
      }

      final targetPlaylist = playlist ??
          Playlist(
            id: 'now_playing',
            name: 'All Songs',
            isYoutubeSynced: false,
            createdAt: DateTime.now(),
          );

      // Fast-path seek only applies if we are ALREADY playing within this exact playlist context
      final isSamePlaylistContext = state.currentPlaylist?.id == targetPlaylist.id;

      // Check if contextTracks matches current queue
      final isSameQueue = contextTracks == null ||
          (state.queue.length == contextTracks.length &&
              state.queue.isNotEmpty &&
              state.queue.first.id == contextTracks.first.id &&
              state.queue.last.id == contextTracks.last.id);

      final isSameContext = isSamePlaylistContext && isSameQueue;
      final existingIndex = state.queue.indexWhere((t) => t.id == track.id);

      if (isSameContext &&
          _playlistSource != null &&
          existingIndex >= 0 &&
          existingIndex < state.queue.length &&
          existingIndex < _playlistSource!.length) {
        final targetTrack = state.queue[existingIndex];

        // If it is already the current track, ensure it's playing or seek to start
        if (state.currentTrack?.id == track.id) {
          if (!_player.playing) {
            await _player.play();
          } else {
            await _player.seek(Duration.zero, index: existingIndex);
          }
          return;
        }

        state = state.copyWith(
          currentIndex: existingIndex,
          currentTrack: () => targetTrack,
          position: Duration.zero,
          duration: Duration(milliseconds: targetTrack.durationMs),
          isPlaying: true,
        );
        _maybeFetchLyrics(targetTrack);
        try {
          await _player.seek(Duration.zero, index: existingIndex);
          if (!_player.playing) {
            await _player.play();
          }
          return;
        } catch (e) {
          debugPrint('Direct seek to existing queue track failed, reloading playlist: $e');
        }
      }

      // Otherwise, initialize new queue from contextTracks (or single track) under targetPlaylist
      final tracks = contextTracks ?? [track];
      await playPlaylist(
        targetPlaylist,
        tracks,
        targetTrack: track,
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
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
  return AudioPlayerController(ref);
});
