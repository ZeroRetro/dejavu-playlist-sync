import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/dejavu_theme.dart';

/// Shows a sleek, informative bottom sheet with playlist technical details.
void showPlaylistDetailsSheet(
    BuildContext context, AppDatabase db, Playlist initialPlaylist) {
  showModalBottomSheet(
    context: context,
    backgroundColor: DejaVuColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StreamBuilder<List<Track>>(
        stream: db.watchTracksInPlaylist(initialPlaylist.id),
        builder: (context, trackSnapshot) {
          final tracks = trackSnapshot.data ?? [];
          final downloadedCount = tracks
              .where((t) => t.downloadStatus == DownloadStatus.completed)
              .length;

          return StreamBuilder<Playlist?>(
            stream: (db.select(db.playlists)
                  ..where((p) => p.id.equals(initialPlaylist.id)))
                .watchSingleOrNull(),
            builder: (context, playlistSnapshot) {
              final currentPlaylist = playlistSnapshot.data ?? initialPlaylist;
              final ytId = currentPlaylist.youtubePlaylistId;
              final ytUrl = ytId != null && ytId.isNotEmpty
                  ? 'https://www.youtube.com/playlist?list=$ytId'
                  : 'Not available';

              final lastUpdatedStr = currentPlaylist.lastSyncedAt != null
                  ? DateFormat.yMMMd()
                      .add_jm()
                      .format(currentPlaylist.lastSyncedAt!)
                  : 'Never synced';

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: DejaVuColors.accent,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Playlist Details',
                            style: TextStyle(
                              color: DejaVuColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildDetailTile(
                        icon: Icons.sync_rounded,
                        iconColor: DejaVuColors.accent,
                        title: 'Sync Source',
                        value: 'YouTube Synced',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDetailTile(
                        icon: Icons.schedule_rounded,
                        title: 'Last Updated',
                        value: lastUpdatedStr,
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDetailTile(
                        icon: Icons.music_note_rounded,
                        title: 'Downloaded Tracks',
                        value: '$downloadedCount of ${tracks.length} songs',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDetailTile(
                        icon: Icons.calendar_today_rounded,
                        title: 'Linked Date',
                        value: DateFormat.yMMMd()
                            .format(currentPlaylist.createdAt),
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDetailTile(
                        icon: Icons.link_rounded,
                        title: 'YouTube URL',
                        value: ytUrl,
                        trailing: ytId != null && ytId.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    size: 18,
                                    color: DejaVuColors.textSecondary),
                                tooltip: 'Copy URL',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: ytUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'YouTube playlist URL copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

Widget _buildDetailTile({
  required IconData icon,
  required String title,
  required String value,
  Color? iconColor,
  Widget? trailing,
}) {
  return Row(
    children: [
      Icon(icon, color: iconColor ?? DejaVuColors.textSecondary, size: 20),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: DejaVuColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DejaVuColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}
