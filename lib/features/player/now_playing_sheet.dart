import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/dejavu_theme.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/lrc_parser.dart';
import 'audio_player_controller.dart';

class NowPlayingSheet extends ConsumerStatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  ConsumerState<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends ConsumerState<NowPlayingSheet> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
        audioPlayerControllerProvider.select((s) => s.currentTrack));

    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: DejaVuColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with minimize chevron and playlist context title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: DejaVuColors.textPrimary,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Minimize player',
                ),
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: DejaVuColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 48), // Symmetrical spacing
              ],
            ),
            const SizedBox(height: 8),

            // 1:1 Aspect Cover Art or Synchronized Lyrics View
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: DejaVuColors.surfaceLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _showLyrics
                      ? Consumer(
                          builder: (context, ref, _) {
                            final pos = ref.watch(
                              audioPlayerControllerProvider
                                  .select((s) => s.position),
                            );
                            return _SyncedLyricsView(
                              key: ValueKey(track.id),
                              lyricsLrc: track.lyricsLrc,
                              currentPosition: pos,
                              onSeek: (target) {
                                ref
                                    .read(audioPlayerControllerProvider.notifier)
                                    .seek(target);
                              },
                            );
                          },
                        )
                      : (track.thumbnailPath != null
                          ? Image.file(
                              File(track.thumbnailPath!),
                              cacheWidth: 600,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: DejaVuColors.textSecondary,
                                  size: 80,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                color: DejaVuColors.textSecondary,
                                size: 80,
                              ),
                            )),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title & Artist row
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: DejaVuColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: DejaVuColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Seek Slider with isolated reactive subscription (prevents cover art & shadow rebuilds)
            const _NowPlayingProgressSection(),

            const SizedBox(height: 12),

            // Playback controls row: [Shuffle] [Prev] (Play/Pause) [Next] [Repeat]
            const _NowPlayingControlsRow(),

            const SizedBox(height: 18),

            // Bottom row: Interactive Lyrics Button & Queue button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _showLyrics = !_showLyrics;
                    });
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showLyrics
                          ? DejaVuColors.accent.withValues(alpha: 0.2)
                          : DejaVuColors.surfaceLight,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color:
                            _showLyrics ? DejaVuColors.accent : Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lyrics_rounded,
                          size: 15,
                          color: _showLyrics
                              ? DejaVuColors.accent
                              : DejaVuColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Lyrics',
                          style: TextStyle(
                            fontSize: 11,
                            color: _showLyrics
                                ? DejaVuColors.accent
                                : DejaVuColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _NowPlayingQueueButton(
                  onTap: () {
                    final ps = ref.read(audioPlayerControllerProvider);
                    _showQueueModal(context, ref, ps);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showQueueModal(
      BuildContext context, WidgetRef ref, PlayerStateSnapshot playerState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DejaVuColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Playing Queue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DejaVuColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: DejaVuColors.surfaceLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${playerState.queue.length} songs',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DejaVuColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: playerState.queue.length,
                    itemBuilder: (context, index) {
                      final t = playerState.queue[index];
                      final isCurrent = index == playerState.currentIndex;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: DejaVuColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: t.thumbnailPath != null
                                    ? Image.file(
                                        File(t.thumbnailPath!),
                                        cacheWidth: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.music_note_rounded,
                                          color: isCurrent
                                              ? DejaVuColors.accent
                                              : DejaVuColors.textSecondary,
                                          size: 20,
                                        ),
                                      )
                                    : Icon(
                                        Icons.music_note_rounded,
                                        color: isCurrent
                                            ? DejaVuColors.accent
                                            : DejaVuColors.textSecondary,
                                        size: 20,
                                      ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: DejaVuColors.accent,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? DejaVuColors.accent
                                : DejaVuColors.textPrimary,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DejaVuColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          DurationFormatter.formatMs(t.durationMs),
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? DejaVuColors.accent
                                : DejaVuColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(audioPlayerControllerProvider.notifier)
                              .playTrack(
                                t,
                                contextTracks: playerState.queue,
                                playlist: playerState.currentPlaylist,
                              );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingProgressSection extends ConsumerWidget {
  const _NowPlayingProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
        audioPlayerControllerProvider.select((s) => s.position));
    final duration = ref.watch(
        audioPlayerControllerProvider.select((s) => s.duration));

    return _AudioSeekSlider(
      position: position,
      duration: duration,
      onSeek: (pos) {
        ref.read(audioPlayerControllerProvider.notifier).seek(pos);
      },
    );
  }
}

class _NowPlayingControlsRow extends ConsumerWidget {
  const _NowPlayingControlsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
        audioPlayerControllerProvider.select((s) => s.isPlaying));
    final isShuffle = ref.watch(
        audioPlayerControllerProvider.select((s) => s.isShuffleEnabled));
    final loopMode = ref.watch(
        audioPlayerControllerProvider.select((s) => s.loopMode));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: isShuffle ? DejaVuColors.accent : DejaVuColors.textSecondary,
            size: 24,
          ),
          onPressed: () {
            ref.read(audioPlayerControllerProvider.notifier).toggleShuffle();
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: DejaVuColors.textPrimary,
            size: 38,
          ),
          onPressed: () {
            ref.read(audioPlayerControllerProvider.notifier).seekToPrevious();
          },
        ),
        GestureDetector(
          onTap: () {
            ref.read(audioPlayerControllerProvider.notifier).togglePlay();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DejaVuColors.accent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            color: DejaVuColors.textPrimary,
            size: 38,
          ),
          onPressed: () {
            ref.read(audioPlayerControllerProvider.notifier).seekToNext();
          },
        ),
        IconButton(
          icon: Icon(
            loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: loopMode != LoopMode.off
                ? DejaVuColors.accent
                : DejaVuColors.textSecondary,
            size: 24,
          ),
          onPressed: () {
            ref.read(audioPlayerControllerProvider.notifier).toggleLoopMode();
          },
        ),
      ],
    );
  }
}

class _NowPlayingQueueButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _NowPlayingQueueButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueCount = ref.watch(
        audioPlayerControllerProvider.select((s) => s.queue.length));

    return TextButton.icon(
      icon: const Icon(
        Icons.queue_music_rounded,
        color: DejaVuColors.textPrimary,
        size: 18,
      ),
      label: Text(
        'Queue ($queueCount)',
        style: const TextStyle(
          color: DejaVuColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
    );
  }
}

class _AudioSeekSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _AudioSeekSlider({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_AudioSeekSlider> createState() => _AudioSeekSliderState();
}

class _AudioSeekSliderState extends State<_AudioSeekSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.duration.inMilliseconds.toDouble();
    final currentMs = widget.position.inMilliseconds
        .clamp(0, widget.duration.inMilliseconds)
        .toDouble();
    final sliderVal = _dragValue ?? (maxMs > 0 ? currentMs : 0.0);
    final displayPos = _dragValue != null
        ? Duration(milliseconds: _dragValue!.toInt())
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: DejaVuColors.accent,
            inactiveTrackColor: DejaVuColors.surfaceLight,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            trackHeight: 3,
          ),
          child: Slider(
            value: maxMs > 0 ? sliderVal.clamp(0.0, maxMs) : 0.0,
            max: maxMs > 0 ? maxMs : 1.0,
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              widget.onSeek(Duration(milliseconds: val.toInt()));
              setState(() {
                _dragValue = null;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.formatDuration(displayPos),
                style: const TextStyle(
                  fontSize: 12,
                  color: DejaVuColors.textSecondary,
                ),
              ),
              Text(
                DurationFormatter.formatDuration(widget.duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: DejaVuColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncedLyricsView extends StatefulWidget {
  final String? lyricsLrc;
  final Duration currentPosition;
  final void Function(Duration) onSeek;

  const _SyncedLyricsView({
    super.key,
    required this.lyricsLrc,
    required this.currentPosition,
    required this.onSeek,
  });

  @override
  State<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<_SyncedLyricsView> {
  List<LrcLine> _lines = [];
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = [];
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _parseLines();
  }

  void _parseLines() {
    _lines = LrcParser.parse(widget.lyricsLrc);
    _lineKeys.clear();
    for (var i = 0; i < _lines.length; i++) {
      _lineKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(covariant _SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricsLrc != oldWidget.lyricsLrc) {
      _parseLines();
      _lastActiveIndex = -1;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    if (_lines.isEmpty) return;

    final activeIndex = LrcParser.findActiveIndex(_lines, widget.currentPosition);

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (activeIndex < _lineKeys.length) {
          final targetContext = _lineKeys[activeIndex].currentContext;
          if (targetContext != null) {
            Scrollable.ensureVisible(
              targetContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
            return;
          }
        }
        if (_scrollController.hasClients) {
          final targetOffset = activeIndex * 48.0;
          _scrollController.animateTo(
            targetOffset.clamp(
                0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_rounded, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'No synchronized lyrics available for this track',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DejaVuColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final activeIndex = LrcParser.findActiveIndex(_lines, widget.currentPosition);

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfHeight = constraints.maxHeight / 2;
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              vertical: (halfHeight - 24.0).clamp(20.0, halfHeight),
              horizontal: 16,
            ),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              final isActive = index == activeIndex;

              return InkWell(
                key: index < _lineKeys.length ? _lineKeys[index] : null,
                onTap: () => widget.onSeek(line.timestamp),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: isActive ? 18 : 15,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white38,
                      height: 1.4,
                    ),
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
