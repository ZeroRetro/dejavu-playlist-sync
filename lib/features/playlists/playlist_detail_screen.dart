import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/dejavu_theme.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/share_utils.dart';
import '../player/audio_player_controller.dart';
import '../player/mini_player.dart';
import '../sync_engine/youtube_sync_service.dart';
import 'widgets/playlist_details_sheet.dart';
import 'widgets/remove_playlist_dialog.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final syncStates = ref.watch(syncControllerProvider);
    final syncState = syncStates[playlist.id];
    final isSyncing = syncState?.isSyncing ?? false;
    final currentPlayingTrackId = ref.watch(
        audioPlayerControllerProvider.select((s) => s.currentTrack?.id));
    final tracksAsync = ref.watch(playlistTracksStreamProvider(playlist.id));

    void triggerSync() {
      if (isSyncing) return;
      ref.read(syncControllerProvider.notifier).syncPlaylist(playlist.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting playlist delta sync...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DejaVuColors.background,
      bottomNavigationBar: const SafeArea(
        top: false,
        child: MiniPlayer(),
      ),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: DejaVuColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded,
                color: DejaVuColors.textPrimary),
            tooltip: 'Share Playlist',
            onPressed: () => ShareUtils.sharePlaylist(context, playlist),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: DejaVuColors.textPrimary),
            color: DejaVuColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) async {
              if (val == 'sync') {
                triggerSync();
              } else if (val == 'details') {
                showPlaylistDetailsSheet(context, db, playlist);
              } else if (val == 'delete') {
                final removed = await showRemovePlaylistDialog(
                  context,
                  ref,
                  playlist,
                );
                if (removed == true && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'sync',
                enabled: !isSyncing,
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: isSyncing
                          ? DejaVuColors.textSecondary
                          : DejaVuColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSyncing ? 'Syncing...' : 'Sync Now',
                      style: TextStyle(
                        color: isSyncing
                            ? DejaVuColors.textSecondary
                            : DejaVuColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: DejaVuColors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Playlist Details',
                        style: TextStyle(color: DejaVuColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Remove Playlist',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: tracksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DejaVuColors.accent),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading playlist tracks: $err',
            style: const TextStyle(color: DejaVuColors.textSecondary),
          ),
        ),
        data: (tracks) {
          final downloadedTracks = tracks
              .where((t) => t.downloadStatus == DownloadStatus.completed)
              .toList();

          return CustomScrollView(
            slivers: [
              // Ambient Header with Cover Art & Gradient
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Ambient Gradient Header Background
                    Container(
                      height: 360,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF421014), // Dark YouTube Crimson tone
                            Color(0xFF22090B),
                            DejaVuColors.background,
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          // Centered 200x200 Shadow-Cast Album Cover
                          Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildCoverArt(playlist, tracks),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Centered Title, Song Count & Total Reproduction Time
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    playlist.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: DejaVuColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    () {
                                      final totalMs = tracks.fold<int>(
                                          0, (sum, t) => sum + t.durationMs);
                                      final durationStr =
                                          DurationFormatter.formatHumanMs(
                                              totalMs);
                                      return durationStr.isNotEmpty
                                          ? '${tracks.length} songs • $durationStr'
                                          : '${tracks.length} songs';
                                    }(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: DejaVuColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Action Row: [Shuffle] [Play All] (aligned right)
                          ModernPlaylistActionRow(
                            onShufflePressed: downloadedTracks.isEmpty
                                ? null
                                : () async {
                                    final list =
                                        List<Track>.from(downloadedTracks)
                                          ..shuffle();
                                    await ref
                                        .read(audioPlayerControllerProvider
                                            .notifier)
                                        .playPlaylist(
                                          playlist,
                                          list,
                                          initialIndex: 0,
                                        );
                                  },
                            onPlayPressed: downloadedTracks.isEmpty
                                ? null
                                : () {
                                    ref
                                        .read(audioPlayerControllerProvider
                                            .notifier)
                                        .playPlaylist(
                                          playlist,
                                          downloadedTracks,
                                          initialIndex: 0,
                                        );
                                  },
                          ),
                          // Live Sync Progress
                          if (isSyncing)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          syncState?.currentTrackTitle != null
                                              ? '⬇ ${syncState!.currentTrackTitle}'
                                              : '⬇ Syncing tracks...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: DejaVuColors.accent,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${syncState?.completedDownloads ?? 0}/${syncState?.totalToDownload ?? 0} (${((syncState?.progress ?? 0) * 100).toInt()}%)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: DejaVuColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: syncState?.progress,
                                      backgroundColor: DejaVuColors.surfaceLight,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              DejaVuColors.accent),
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Retry failed downloads banner
                          if (!isSyncing &&
                              tracks.any((t) =>
                                  t.downloadStatus == DownloadStatus.failed))
                            InkWell(
                              onTap: triggerSync,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${tracks.where((t) => t.downloadStatus == DownloadStatus.failed).length} song(s) failed to download. Tap to retry.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.refresh_rounded,
                                        color: Colors.redAccent, size: 18),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Track List
              if (tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isSyncing
                            ? 'Fetching tracks from playlist...'
                            : 'No tracks synced yet. Tap ⋮ and choose Sync Now.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: DejaVuColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = tracks[index];
                      final isCurrentTrack =
                          currentPlayingTrackId == track.id;
                      final isCompleted =
                          track.downloadStatus == DownloadStatus.completed;
                      final isFailed =
                          track.downloadStatus == DownloadStatus.failed;

                      return ModernTrackTile(
                        track: track,
                        isPlaying: isCurrentTrack,
                        onTap: isCompleted
                            ? () {
                                ref
                                    .read(audioPlayerControllerProvider.notifier)
                                    .playPlaylist(
                                      playlist,
                                      downloadedTracks,
                                      targetTrack: track,
                                    );
                              }
                            : (isFailed ? triggerSync : () {}),
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoverArt(Playlist playlist, List<Track> tracks) {
    String? thumb = playlist.thumbnailPath;
    if (thumb == null && tracks.isNotEmpty) {
      thumb = tracks.first.thumbnailPath;
    }
    if (thumb != null) {
      return Image.file(
        File(thumb),
        cacheWidth: 500,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: DejaVuColors.surfaceLight,
          child: const Center(
            child: Icon(
              Icons.queue_music_rounded,
              color: DejaVuColors.textSecondary,
              size: 64,
            ),
          ),
        ),
      );
    }
    return Container(
      color: DejaVuColors.surfaceLight,
      child: const Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: DejaVuColors.textSecondary,
          size: 64,
        ),
      ),
    );
  }
}
