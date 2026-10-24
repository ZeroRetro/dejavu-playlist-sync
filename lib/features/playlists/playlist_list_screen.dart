import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/dejavu_theme.dart';
import '../../core/utils/demo_seeder.dart';
import '../../core/utils/share_utils.dart';
import '../../core/widgets/about_app_sheet.dart';
import '../sync_engine/youtube_sync_service.dart';
import 'new_playlist_modal.dart';
import 'playlist_detail_screen.dart';
import 'widgets/playlist_details_sheet.dart';
import 'widgets/remove_playlist_dialog.dart';

class PlaylistListScreen extends ConsumerWidget {
  const PlaylistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final syncStates = ref.watch(syncControllerProvider);
    final playlistsAsync = ref.watch(playlistsWithCountsStreamProvider);

    return Scaffold(
      backgroundColor: DejaVuColors.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => showAboutAppSheet(context),
          behavior: HitTestBehavior.opaque,
          child: const Text(
            'Playlists',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: DejaVuColors.textPrimary,
            ),
          ),
        ),
        actions: [
          // Refresh All Sync
          IconButton(
            icon: const Icon(Icons.sync_rounded,
                color: DejaVuColors.textPrimary, size: 24),
            tooltip: 'Sync All Playlists',
            onPressed: () async {
              final playlists = await db.watchPlaylistsWithCounts().first;
              if (playlists.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No playlists to sync.')),
                  );
                }
                return;
              }
              for (final p in playlists) {
                ref
                    .read(syncControllerProvider.notifier)
                    .syncPlaylist(p.playlist.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Syncing ${playlists.length} playlist(s)...')),
                );
              }
            },
          ),
          // Add Playlist
          IconButton(
            icon: const Icon(Icons.add_rounded,
                color: DejaVuColors.textPrimary, size: 28),
            tooltip: 'Add Playlist',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const NewPlaylistModal(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: playlistsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DejaVuColors.accent),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading playlists: $err',
            style: const TextStyle(color: DejaVuColors.textSecondary),
          ),
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync_disabled_rounded,
                      size: 56,
                      color: DejaVuColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No playlists synced yet',
                      style: TextStyle(
                        color: DejaVuColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paste a public or unlisted playlist link to synchronize tracks for offline playback.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DejaVuColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DejaVuColors.accent,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add Playlist',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => const NewPlaylistModal(),
                        );
                      },
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => DemoSeeder.seedCreativeCommonsShowcase(db),
                        child: const Text(
                          'Load Demo Showcase',
                          style: TextStyle(
                            color: DejaVuColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final item = playlists[index];
              final playlist = item.playlist;
              final syncState = syncStates[playlist.id];
              final isSyncing = syncState?.isSyncing ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: DejaVuColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(
                          playlist: playlist,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Cover art
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: DejaVuColors.surfaceLight,
                            child: playlist.thumbnailPath != null
                                ? Image.file(
                                    File(playlist.thumbnailPath!),
                                    cacheWidth: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.queue_music_rounded,
                                      color: DejaVuColors.textSecondary,
                                      size: 28,
                                    ),
                                  )
                                : const Icon(
                                    Icons.queue_music_rounded,
                                    color: DejaVuColors.textSecondary,
                                    size: 28,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DejaVuColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.downloadedTracks < item.totalTracks
                                    ? '${item.totalTracks} songs (${item.downloadedTracks} downloaded)'
                                    : '${item.totalTracks} songs',
                                style: const TextStyle(
                                  color: DejaVuColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (isSyncing)
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.6,
                                        color: DejaVuColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Syncing (${syncState?.completedDownloads ?? 0}/${syncState?.totalToDownload ?? 0})...',
                                      style: const TextStyle(
                                        color: DejaVuColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  playlist.lastSyncedAt != null
                                      ? 'Updated ${DateFormat.MMMd().add_jm().format(playlist.lastSyncedAt!)}'
                                      : 'Never synced',
                                  style: const TextStyle(
                                    color: DejaVuColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: DejaVuColors.textSecondary,
                            size: 20,
                          ),
                          color: DejaVuColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (val) {
                            if (val == 'share') {
                              ShareUtils.sharePlaylist(context, playlist);
                            } else if (val == 'sync') {
                              ref
                                  .read(syncControllerProvider.notifier)
                                  .syncPlaylist(playlist.id);
                            } else if (val == 'details') {
                              showPlaylistDetailsSheet(context, db, playlist);
                            } else if (val == 'delete') {
                              showRemovePlaylistDialog(context, ref, playlist);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded,
                                      color: DejaVuColors.textPrimary, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Share YouTube Playlist',
                                    style: TextStyle(
                                      color: DejaVuColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'sync',
                              child: Row(
                                children: [
                                  Icon(Icons.sync_rounded,
                                      color: DejaVuColors.textPrimary, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sync Now',
                                    style: TextStyle(
                                      color: DejaVuColors.textPrimary,
                                      fontSize: 13,
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
                                      color: DejaVuColors.textPrimary, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Playlist Details',
                                    style: TextStyle(
                                      color: DejaVuColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Remove Playlist',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
