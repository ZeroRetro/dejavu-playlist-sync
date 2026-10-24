import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

class ShareUtils {
  /// Shares the original YouTube playlist URL using the native platform share dialog.
  static Future<void> sharePlaylist(
    BuildContext context,
    Playlist playlist, {
    Rect? sharePositionOrigin,
  }) async {
    final ytId = playlist.youtubePlaylistId;
    if (ytId == null || ytId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No YouTube link available for this playlist.'),
          ),
        );
      }
      return;
    }

    final url = 'https://www.youtube.com/playlist?list=$ytId';

    Rect? origin = sharePositionOrigin;
    if (origin == null && context.mounted) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          origin = box.localToGlobal(Offset.zero) & box.size;
        }
      } catch (_) {
        origin = null;
      }
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: url,
          subject: playlist.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('ShareUtils.sharePlaylist failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share playlist: $e'),
          ),
        );
      }
    }
  }
}
