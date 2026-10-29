import 'dart:io';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../utils/duration_formatter.dart';

class DejaVuColors {
  static const Color background = Color(0xFF0F0F0F); // YT Music Carbon
  static const Color surface = Color(0xFF1E1E1E);    // Cards & Sheets
  static const Color surfaceLight = Color(0xFF272727); // Pills & elevated surfaces
  static const Color miniPlayer = Color(0xFF282828); // Floating Bar
  static const Color accent = Color(0xFFC0151B);     // Dark YouTube Red
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
}

class DejaVuTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DejaVuColors.background,
      colorScheme: const ColorScheme.dark(
        primary: DejaVuColors.accent,
        surface: DejaVuColors.surface,
        onSurface: DejaVuColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: DejaVuColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: DejaVuColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: DejaVuColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DejaVuColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: DejaVuColors.accent,
        inactiveTrackColor: DejaVuColors.surfaceLight,
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayColor: DejaVuColors.accent.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DejaVuColors.background,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? DejaVuColors.textPrimary
                : DejaVuColors.textSecondary,
          );
        }),
      ),
    );
  }
}

// =============================================================================
// 1. PLAYLIST ACTION BAR (WITH OVERSIZED PLAY FAB & SHUFFLE)
// =============================================================================
class ModernPlaylistActionRow extends StatelessWidget {
  final VoidCallback? onPlayPressed;
  final VoidCallback? onShufflePressed;

  const ModernPlaylistActionRow({
    super.key,
    required this.onPlayPressed,
    required this.onShufflePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: onShufflePressed,
            icon: const Icon(Icons.shuffle_rounded),
            color: DejaVuColors.textSecondary,
            iconSize: 26,
            tooltip: 'Shuffle',
          ),
          const SizedBox(width: 12),
          // Oversized 56px circular Play button
          SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              onPressed: onPlayPressed,
              backgroundColor: DejaVuColors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.play_arrow_rounded, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. TRACK ROW (WITH THUMBNAIL, TITLE, ARTIST & DURATION)
// =============================================================================
class ModernTrackTile extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const ModernTrackTile({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 48x48 Rounded Cover Thumbnail with lightweight native decode
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: track.thumbnailPath != null
                    ? Image.file(
                        File(track.thumbnailPath!),
                        cacheWidth: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: DejaVuColors.surfaceLight,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: DejaVuColors.textSecondary,
                          ),
                        ),
                      )
                    : Container(
                        color: DejaVuColors.surfaceLight,
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: DejaVuColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title & Inline Status Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? DejaVuColors.accent
                          : DejaVuColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusBadge(track.downloadStatus),
                      Expanded(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DejaVuColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (track.durationMs > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          DurationFormatter.formatMs(track.durationMs),
                          style: const TextStyle(
                            color: DejaVuColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onMoreTap != null)
              IconButton(
                onPressed: onMoreTap,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: DejaVuColors.textSecondary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Renders download status indicator (spinner during download/transcoding, error icon if failed)
  Widget _buildStatusBadge(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return const SizedBox.shrink(); // No arrow icon needed
      case DownloadStatus.downloading:
      case DownloadStatus.converting:
        return const Padding(
          padding: EdgeInsets.only(right: 6),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: DejaVuColors.accent,
            ),
          ),
        );
      case DownloadStatus.failed:
        return const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: Colors.redAccent,
          ),
        );
      case DownloadStatus.pending:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// 3. FLOATING ROUNDED MINI-PLAYER
// =============================================================================
class ModernFloatingMiniPlayer extends StatelessWidget {
  final Track currentTrack;
  final bool isPlaying;
  final double? progress; // Optional backwards compatible fallback
  final Widget? progressBar;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onTapExpand;

  const ModernFloatingMiniPlayer({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    this.progress,
    this.progressBar,
    required this.onPlayPause,
    required this.onNext,
    required this.onTapExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: DejaVuColors.miniPlayer,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTapExpand,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: currentTrack.thumbnailPath != null
                            ? Image.file(
                                File(currentTrack.thumbnailPath!),
                                key: ValueKey(currentTrack.id),
                                cacheWidth: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: DejaVuColors.surfaceLight,
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: DejaVuColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                color: DejaVuColors.surfaceLight,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: DejaVuColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTapExpand,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: DejaVuColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              currentTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: DejaVuColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onPlayPause,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: DejaVuColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: onNext,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: DejaVuColors.textPrimary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              // Thin 2px progress bar along the bottom edge
              progressBar ??
                  LinearProgressIndicator(
                    value: (progress ?? 0.0).clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(DejaVuColors.accent),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
