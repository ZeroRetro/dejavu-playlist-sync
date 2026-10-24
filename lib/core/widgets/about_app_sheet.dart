import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/dejavu_theme.dart';

/// Shows an informative "About" sheet when tapping the app bar title.
void showAboutAppSheet(BuildContext context) {
  const repoUrl = 'https://github.com/ZeroRetro/dejavu-playlist-sync';

  showModalBottomSheet(
    context: context,
    backgroundColor: DejaVuColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top drag indicator
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // App Logo
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: DejaVuColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: DejaVuColors.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),

              // App Name
              const Text(
                'DejaVu Playlist Sync',
                style: TextStyle(
                  color: DejaVuColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),

              // Dynamic Version pill
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final versionStr = snapshot.hasData
                      ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                      : '1.0.0+1';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: DejaVuColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Version $versionStr',
                      style: const TextStyle(
                        color: DejaVuColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Description banner requested by user
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: DejaVuColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Offline playlist synchronizer and media archiver',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DejaVuColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Direct Link to GitHub
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final uri = Uri.parse(repoUrl);
                    try {
                      final launched = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched) throw 'Could not launch';
                    } catch (_) {
                      await Clipboard.setData(
                          const ClipboardData(text: repoUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'GitHub link copied to clipboard: $repoUrl'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.code_rounded,
                          color: DejaVuColors.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GitHub Repository',
                                style: TextStyle(
                                  color: DejaVuColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'ZeroRetro/dejavu-playlist-sync',
                                style: TextStyle(
                                  color: DejaVuColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: DejaVuColors.textSecondary,
                          ),
                          tooltip: 'Copy GitHub URL',
                          onPressed: () {
                            Clipboard.setData(
                                const ClipboardData(text: repoUrl));
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'GitHub link copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: DejaVuColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
