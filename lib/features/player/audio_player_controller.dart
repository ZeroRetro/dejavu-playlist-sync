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
  Timer? _stallWatchdogTimer;
  bool _disposed = false;
  DateTime _lastPositionEmission = DateTime.fromMillisecondsSinceEpoch(0);

  AudioPlayerController([this._ref, AudioPlayer? player])
      : _player = player ??
            AudioPlayer(
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

      if (processingState == ProcessingState.completed) {
        if (state.loopMode == LoopMode.one) {
          seek(Duration.zero);
          play();
        } else if (_player.hasNext ||
            (state.loopMode == LoopMode.all && state.queue.isNotEmpty)) {
          seekToNext();
        } else {
          state = state.copyWith(
            isPlaying: false,
            isBuffering: false,
            position: state.duration,
          );
        }
        return;
      }

      if (state.currentTrack != null) {
        state = state.copyWith(
          isPlaying: isPlaying,
          isBuffering: isBuffering,
        );
      }
    }));

    _subscriptions.add(_player.positionStream.listen((pos) {
      // If position has advanced past 100ms, playback is healthy and active.
      // Cancel any pending stall watchdog immediately to prevent audible rewind restarts.
      if (pos.inMilliseconds > 100 && _stallWatchdogTimer != null) {
        _stallWatchdogTimer?.cancel();
        _stallWatchdogTimer = null;
      }

      if (!_isLoadingSource && state.currentTrack != null) {
        // Track roll-over detection if index event lagged behind ExoPlayer transition
        final pIdx = _player.currentIndex;
        if (pIdx != null &&
            pIdx >= 0 &&
            pIdx < state.queue.length &&
            pIdx != state.currentIndex &&
            state.duration.inMilliseconds > 5000 &&
            state.position.inMilliseconds >
                (state.duration.inMilliseconds * 0.6) &&
            pos.inMilliseconds < 2000) {
          final nextTrack = state.queue[pIdx];
          state = state.copyWith(
            currentIndex: pIdx,
            currentTrack: () => nextTrack,
            duration: Duration(milliseconds: nextTrack.durationMs),
            position: pos,
          );
          _maybeFetchLyrics(nextTrack);
          return;
        }

        final now = DateTime.now();
        final diff = (pos - state.position).inMilliseconds.abs();
        // Throttle high-frequency position emissions to ~200ms intervals (5 FPS) unless a jump/seek occurs
        // or playback reaches the end of the track. This reduces Riverpod/UI thrashing by >75%.
        if (diff > 400 ||
            now.difference(_lastPositionEmission).inMilliseconds >= 200 ||
            (state.duration.inMilliseconds > 0 && pos >= state.duration)) {
          _lastPositionEmission = now;
          state = state.copyWith(position: pos);
        }
      }
    }));

    _subscriptions.add(_player.durationStream.listen((dur) {
      if (!_isLoadingSource && dur != null && state.currentTrack != null) {
        state = state.copyWith(duration: dur);
      }
    }));

    _subscriptions.add(_player.currentIndexStream.listen((index) {
      if (!_isLoadingSource &&
          index != null &&
          index >= 0 &&
          index < state.queue.length) {
        final track = state.queue[index];
        if (state.currentTrack?.id != track.id || state.currentIndex != index) {
          state = state.copyWith(
            currentIndex: index,
            currentTrack: () => track,
            duration: Duration(milliseconds: track.durationMs),
          );
          _maybeFetchLyrics(track);
          if (state.isPlaying || _player.playing) {
            _scheduleStallWatchdog(index);
          }
        }
      }
    }));

    _subscriptions.add(_player.sequenceStateStream.listen((seqState) {
      if (_isLoadingSource || seqState == null) return;
      final currentSource = seqState.currentSource;
      final mediaItem = currentSource?.tag as MediaItem?;
      int? targetIndex;
      Track? targetTrack;

      if (mediaItem != null) {
        final idx = state.queue.indexWhere((t) => t.id == mediaItem.id);
        if (idx >= 0) {
          targetIndex = idx;
          targetTrack = state.queue[idx];
        } else {
          // Stale event from another playlist source, ignore
          return;
        }
      } else if (seqState.currentIndex >= 0 &&
          seqState.currentIndex < state.queue.length) {
        targetIndex = seqState.currentIndex;
        targetTrack = state.queue[targetIndex];
      }

      if (targetTrack != null && targetIndex != null) {
        if (state.currentTrack?.id != targetTrack.id ||
            state.currentIndex != targetIndex) {
          state = state.copyWith(
            currentIndex: targetIndex,
            currentTrack: () => targetTrack,
            duration: Duration(milliseconds: targetTrack.durationMs),
          );
          _maybeFetchLyrics(targetTrack);
          if (state.isPlaying || _player.playing) {
            _scheduleStallWatchdog(targetIndex);
          }
        }
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
        debugPrint('AudioPlayer playback event error: $error');
        state = state.copyWith(isPlaying: false, isBuffering: false);
        // Automatically attempt to advance to the next track if available
        seekToNext();
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

  /// Safely monitors track transitions to resolve 0:00 audio sink stalls on Android
  /// without interrupting normal playback or aborting in-flight media loading.
  void _scheduleStallWatchdog([int? targetIndex]) {
    _stallWatchdogTimer?.cancel();
    _stallWatchdogTimer = Timer(const Duration(milliseconds: 1200), () async {
      try {
        if (_disposed || !mounted || _isLoadingSource) return;
        if (!state.isPlaying && !_player.playing) return;

        // 1. If the decoder is still loading the media source from disk, reschedule
        if (_player.processingState == ProcessingState.loading) {
          _scheduleStallWatchdog(targetIndex);
          return;
        }

        // 2. Only nudge if playback is genuinely stuck at 0:00 (position <= 20ms) despite being ready or buffering
        final currentPos = _player.position;
        if (currentPos.inMilliseconds <= 20 &&
            (_player.processingState == ProcessingState.ready ||
                _player.processingState == ProcessingState.buffering)) {
          debugPrint(
              'Playback stall detected at position $currentPos. Auto-nudging AudioTrack sink...');
          if (targetIndex != null) {
            await _player.seek(const Duration(milliseconds: 50),
                index: targetIndex);
          } else {
            await _player.seek(const Duration(milliseconds: 50));
          }
          await _player.play();
        }
      } catch (e) {
        debugPrint('Stall watchdog notice: $e');
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
    final token = ++_operationToken;
    _stallWatchdogTimer?.cancel();
    _stallWatchdogTimer = null;

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

    // Suppress stale stream events from the previous playlist
    _isLoadingSource = true;

    // Optimistically update UI immediately to the target playlist and track
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

    try {
      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      ).timeout(const Duration(seconds: 4));

      if (_operationToken != token) return;

      // Explicitly call play() so playback begins immediately and never stalls at 0:00!
      await _player.play();
      _scheduleStallWatchdog(safeIndex);
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    } finally {
      if (_operationToken == token) {
        _isLoadingSource = false;
        // Guarantee controller state is aligned with target track and playlist
        if (state.currentIndex != safeIndex ||
            state.currentTrack?.id != actualTargetTrack.id ||
            state.currentPlaylist?.id != playlist.id) {
          state = state.copyWith(
            currentPlaylist: () => playlist,
            currentIndex: safeIndex,
            currentTrack: () => actualTargetTrack,
            duration: Duration(milliseconds: actualTargetTrack.durationMs),
            isPlaying: true,
          );
        }
      }
    }
  }

  int _operationToken = 0;

  /// Play a single track directly
  Future<void> playTrack(
    Track track, {
    List<Track>? contextTracks,
    Playlist? playlist,
  }) async {
    final myToken = ++_operationToken;
    try {
      if (track.localFilePath == null) return;
      try {
        final f = File(track.localFilePath!);
        if (!f.existsSync() || f.lengthSync() < 50 * 1024) {
          debugPrint(
              'Audio file is missing or invalid (< 50KB): ${track.localFilePath}');
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
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          );

      // Fast-path seek: if we are already in the same playlist context and track is in queue
      final isSamePlaylistContext =
          state.currentPlaylist?.id == targetPlaylist.id;
      final existingIndex = state.queue.indexWhere((t) => t.id == track.id);

      if (isSamePlaylistContext &&
          _playlistSource != null &&
          existingIndex >= 0 &&
          existingIndex < state.queue.length &&
          existingIndex < _playlistSource!.length) {
        final targetTrack = state.queue[existingIndex];

        // If it is already the current track, ensure it's playing or seek to start
        if (state.currentTrack?.id == track.id) {
          try {
            await _player
                .seek(Duration.zero, index: existingIndex)
                .timeout(const Duration(seconds: 3));
            await _player.play();
            _scheduleStallWatchdog(existingIndex);
          } catch (_) {}
          return;
        }

        // Optimistically update UI immediately so user sees the track highlighted right away
        state = state.copyWith(
          currentIndex: existingIndex,
          currentTrack: () => targetTrack,
          position: Duration.zero,
          duration: Duration(milliseconds: targetTrack.durationMs),
          isPlaying: true,
        );
        _maybeFetchLyrics(targetTrack);

        try {
          await _player
              .seek(Duration.zero, index: existingIndex)
              .timeout(const Duration(seconds: 3));
          if (_operationToken != myToken) return;
          // ALWAYS ensure play is called so player does not stay paused at 0:00!
          await _player.play();
          _scheduleStallWatchdog(existingIndex);
          return;
        } catch (e) {
          debugPrint(
              'Direct seek to existing queue track failed, reloading playlist: $e');
        }
      }

      if (_operationToken != myToken) return;

      // Otherwise, initialize new queue from contextTracks (or single track) under targetPlaylist
      final tracks = contextTracks ?? [track];
      await playPlaylist(
        targetPlaylist,
        tracks,
        targetTrack: track,
      );
    } catch (e) {
      debugPrint('Error in playTrack: $e');
    }
  }

  Future<void> play() async {
    await _player.play();
    _scheduleStallWatchdog(state.currentIndex >= 0 ? state.currentIndex : null);
  }

  Future<void> pause() async {
    _stallWatchdogTimer?.cancel();
    await _player.pause();
  }

  /// Stop playback, unload current playlist/queue, and completely reset player state snapshot
  Future<void> stopAndClear() async {
    _stallWatchdogTimer?.cancel();
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
      _stallWatchdogTimer?.cancel();
      await _player.pause();
    } else {
      await _player.play();
      _scheduleStallWatchdog(
          state.currentIndex >= 0 ? state.currentIndex : null);
    }
  }

  Future<void> seek(Duration position) async {
    _lastPositionEmission = DateTime.now();
    state = state.copyWith(position: position);
    await _player.seek(position);
  }

  Future<void> seekToNext() async {
    final myToken = ++_operationToken;
    try {
      int? targetIndex = _player.nextIndex;
      if (targetIndex == null && state.queue.isNotEmpty) {
        if (state.isShuffleEnabled &&
            _player.shuffleIndices != null &&
            _player.shuffleIndices!.isNotEmpty) {
          final pos = _player.shuffleIndices!.indexOf(state.currentIndex);
          if (pos >= 0 && pos + 1 < _player.shuffleIndices!.length) {
            targetIndex = _player.shuffleIndices![pos + 1];
          } else if (state.loopMode == LoopMode.all) {
            targetIndex = _player.shuffleIndices!.first;
          }
        } else {
          final next = state.currentIndex + 1;
          if (next < state.queue.length) {
            targetIndex = next;
          } else if (state.loopMode == LoopMode.all) {
            targetIndex = 0;
          }
        }
      }

      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < state.queue.length) {
        final nextTrack = state.queue[targetIndex];
        state = state.copyWith(
          currentIndex: targetIndex,
          currentTrack: () => nextTrack,
          position: Duration.zero,
          duration: Duration(milliseconds: nextTrack.durationMs),
          isPlaying: true,
        );
        _maybeFetchLyrics(nextTrack);
      }

      if (_playlistSource != null &&
          targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < _playlistSource!.length) {
        await _player
            .seek(Duration.zero, index: targetIndex)
            .timeout(const Duration(seconds: 3));
        if (_operationToken != myToken) return;
        await _player.play();
        _scheduleStallWatchdog(targetIndex);
      } else if (_player.hasNext) {
        await _player.seekToNext().timeout(const Duration(seconds: 3));
        if (_operationToken != myToken) return;
        await _player.play();
        if (targetIndex != null) _scheduleStallWatchdog(targetIndex);
      } else if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
        await _player
            .seek(Duration.zero, index: 0)
            .timeout(const Duration(seconds: 3));
        if (_operationToken != myToken) return;
        await _player.play();
        _scheduleStallWatchdog(0);
      }
    } catch (e) {
      debugPrint('Error seeking to next: $e');
    }
  }

  Future<void> seekToPrevious() async {
    final myToken = ++_operationToken;
    try {
      if (_player.position.inSeconds > 3) {
        state = state.copyWith(position: Duration.zero);
        await _player.seek(Duration.zero).timeout(const Duration(seconds: 3));
        if (_operationToken != myToken) return;
        await _player.play();
      } else {
        int? targetIndex = _player.previousIndex;
        if (targetIndex == null && state.queue.isNotEmpty) {
          if (state.isShuffleEnabled &&
              _player.shuffleIndices != null &&
              _player.shuffleIndices!.isNotEmpty) {
            final pos = _player.shuffleIndices!.indexOf(state.currentIndex);
            if (pos > 0) {
              targetIndex = _player.shuffleIndices![pos - 1];
            } else if (state.loopMode == LoopMode.all) {
              targetIndex = _player.shuffleIndices!.last;
            }
          } else {
            final prev = state.currentIndex - 1;
            if (prev >= 0) {
              targetIndex = prev;
            } else if (state.loopMode == LoopMode.all) {
              targetIndex = state.queue.length - 1;
            }
          }
        }

        if (targetIndex != null &&
            targetIndex >= 0 &&
            targetIndex < state.queue.length) {
          final prevTrack = state.queue[targetIndex];
          state = state.copyWith(
            currentIndex: targetIndex,
            currentTrack: () => prevTrack,
            position: Duration.zero,
            duration: Duration(milliseconds: prevTrack.durationMs),
            isPlaying: true,
          );
          _maybeFetchLyrics(prevTrack);
        }

        if (_playlistSource != null &&
            targetIndex != null &&
            targetIndex >= 0 &&
            targetIndex < _playlistSource!.length) {
          await _player
              .seek(Duration.zero, index: targetIndex)
              .timeout(const Duration(seconds: 3));
          if (_operationToken != myToken) return;
          await _player.play();
          _scheduleStallWatchdog(targetIndex);
        } else if (_player.hasPrevious) {
          await _player.seekToPrevious().timeout(const Duration(seconds: 3));
          if (_operationToken != myToken) return;
          await _player.play();
          if (targetIndex != null) _scheduleStallWatchdog(targetIndex);
        } else if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
          final lastIdx = state.queue.length - 1;
          await _player
              .seek(Duration.zero, index: lastIdx)
              .timeout(const Duration(seconds: 3));
          if (_operationToken != myToken) return;
          await _player.play();
          _scheduleStallWatchdog(lastIdx);
        }
      }
    } catch (e) {
      debugPrint('Error seeking to previous: $e');
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
    _disposed = true;
    _stallWatchdogTimer?.cancel();
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
