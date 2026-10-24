import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/dejavu_theme.dart';
import '../../player/audio_player_controller.dart';

/// Shows a dialog to remove a playlist with the option to also delete
/// downloaded audio files from storage, protecting tracks used in other playlists.
Future<bool?> showRemovePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) {
  final db = ref.read(appDatabaseProvider);
  bool deleteAudioFiles = false;

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            backgroundColor: DejaVuColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Remove Playlist',
              style: TextStyle(
                color: DejaVuColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to remove "${playlist.name}" from DejaVu?',
                  style: const TextStyle(
                    color: DejaVuColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: DejaVuColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CheckboxListTile(
                    value: deleteAudioFiles,
                    dense: true,
                    activeColor: DejaVuColors.accent,
                    checkColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    title: const Text(
                      'Delete downloaded songs from device',
                      style: TextStyle(
                        color: DejaVuColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Songs used in your other playlists will be kept safe.',
                      style: TextStyle(
                        color: DejaVuColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => deleteAudioFiles = val ?? false),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: DejaVuColors.textSecondary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () async {
                  Navigator.pop(ctx, true);
                  final playerNotifier =
                      ref.read(audioPlayerControllerProvider.notifier);
                  final playerState = ref.read(audioPlayerControllerProvider);
                  final isPlayingThisPlaylist =
                      playerState.currentPlaylist?.id == playlist.id;

                  await db.deletePlaylist(
                    playlist.id,
                    deleteAudioFiles: deleteAudioFiles,
                  );

                  final remainingPlaylists = await db.getAllPlaylists();
                  if (remainingPlaylists.isEmpty || isPlayingThisPlaylist) {
                    await playerNotifier.stopAndClear();
                  } else if (playerState.currentTrack != null) {
                    final trackStillExists =
                        await db.getTrackById(playerState.currentTrack!.id);
                    final fileStillExists =
                        playerState.currentTrack!.localFilePath != null &&
                            File(playerState.currentTrack!.localFilePath!)
                                .existsSync();
                    if (trackStillExists == null || !fileStillExists) {
                      await playerNotifier.stopAndClear();
                    }
                  }
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
