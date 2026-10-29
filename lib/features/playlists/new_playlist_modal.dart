import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../../core/theme/dejavu_theme.dart';
import '../sync_engine/youtube_sync_service.dart';

class NewPlaylistModal extends ConsumerStatefulWidget {
  const NewPlaylistModal({super.key});

  @override
  ConsumerState<NewPlaylistModal> createState() => _NewPlaylistModalState();
}

class _NewPlaylistModalState extends ConsumerState<NewPlaylistModal> {
  final _urlController = TextEditingController();
  final bool _convertToMp3 = false; // native M4A/AAC for lossless & battery efficiency
  bool _keepAudioWhenRemoved = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a YouTube Playlist URL or ID.');
      return;
    }

    final parsedId = yt.PlaylistId.parsePlaylistId(url);
    if (parsedId == null) {
      setState(() => _errorMessage = 'Please enter a valid YouTube Playlist URL or ID.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Fire background delta sync
      ref.read(syncControllerProvider.notifier).createAndSync(
            url,
            convertToMp3: _convertToMp3,
            deleteOrphans: !_keepAudioWhenRemoved,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist added! Syncing tracks in background...'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: DejaVuColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sync Playlist',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DejaVuColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: DejaVuColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'Enter any public or unlisted playlist URL (such as YouTube). DejaVu will automatically parse metadata and synchronize audio tracks for offline playback.',
                style: TextStyle(
                  color: DejaVuColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Playlist URL input
              const Text(
                'Playlist URL or ID',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: DejaVuColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                autofocus: true,
                style: const TextStyle(color: DejaVuColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/playlist?list=...',
                  hintStyle:
                      const TextStyle(color: DejaVuColors.textSecondary),
                  filled: true,
                  fillColor: DejaVuColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: DejaVuColors.accent, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 14),

              // Removal Policy
              CheckboxListTile(
                dense: true,
                value: _keepAudioWhenRemoved,
                activeColor: DejaVuColors.accent,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Preserve downloaded tracks on sync update',
                  style: TextStyle(
                      color: DejaVuColors.textPrimary, fontSize: 13),
                ),
                subtitle: const Text(
                  'Retain existing offline audio files in library even if unlinked remotely',
                  style: TextStyle(
                      color: DejaVuColors.textSecondary, fontSize: 12),
                ),
                onChanged: (val) =>
                    setState(() => _keepAudioWhenRemoved = val ?? true),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: DejaVuColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DejaVuColors.accent,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add & Sync',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
