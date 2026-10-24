import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/dejavu_theme.dart';
import 'audio_player_controller.dart';
import 'now_playing_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(
        audioPlayerControllerProvider.select((s) => s.currentTrack));

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = ref.watch(
        audioPlayerControllerProvider.select((s) => s.isPlaying));

    return ModernFloatingMiniPlayer(
      currentTrack: currentTrack,
      isPlaying: isPlaying,
      progressBar: const _MiniPlayerProgressBar(),
      onPlayPause: () {
        ref.read(audioPlayerControllerProvider.notifier).togglePlay();
      },
      onNext: () {
        ref.read(audioPlayerControllerProvider.notifier).seekToNext();
      },
      onTapExpand: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const NowPlayingSheet(),
        );
      },
    );
  }
}

class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioPlayerControllerProvider.select((s) {
      final total = s.duration.inMilliseconds;
      if (total <= 0) return 0.0;
      return (s.position.inMilliseconds / total).clamp(0.0, 1.0);
    }));

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: Colors.white12,
      valueColor: const AlwaysStoppedAnimation<Color>(DejaVuColors.accent),
    );
  }
}
