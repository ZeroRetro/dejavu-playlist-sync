import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/dejavu_theme.dart';
import '../../core/widgets/about_app_sheet.dart';
import '../player/audio_player_controller.dart';
import '../sync_engine/youtube_sync_service.dart';

enum LibrarySortBy {
  title,
  artist,
  recentlyAdded,
  duration,
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  LibrarySortBy _sortBy = LibrarySortBy.title;
  bool _sortAscending = true;
  DownloadStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayingTrackId = ref.watch(
        audioPlayerControllerProvider.select((s) => s.currentTrack?.id));
    final tracksAsync = ref.watch(allTracksStreamProvider);
    final allTracks = tracksAsync.valueOrNull ?? [];

    final failedCount =
        allTracks.where((t) => t.downloadStatus == DownloadStatus.failed).length;
    final downloadingCount = allTracks
        .where((t) =>
            t.downloadStatus == DownloadStatus.downloading ||
            t.downloadStatus == DownloadStatus.converting)
        .length;

    var filtered = _searchQuery.isEmpty
        ? allTracks
        : allTracks.where((t) {
            return t.title.toLowerCase().contains(_searchQuery) ||
                t.artist.toLowerCase().contains(_searchQuery);
          }).toList();

    if (_statusFilter != null) {
      if (_statusFilter == DownloadStatus.downloading) {
        filtered = filtered
            .where((t) =>
                t.downloadStatus == DownloadStatus.downloading ||
                t.downloadStatus == DownloadStatus.converting)
            .toList();
      } else {
        filtered =
            filtered.where((t) => t.downloadStatus == _statusFilter).toList();
      }
    }

    final sortedList = List<Track>.from(filtered);
    sortedList.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case LibrarySortBy.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case LibrarySortBy.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case LibrarySortBy.recentlyAdded:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case LibrarySortBy.duration:
          cmp = a.durationMs.compareTo(b.durationMs);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    filtered = sortedList;

    return Scaffold(
          backgroundColor: DejaVuColors.background,
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => showAboutAppSheet(context),
              behavior: HitTestBehavior.opaque,
              child: const Text(
                'All Songs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DejaVuColors.textPrimary,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Modern Search Input Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: DejaVuColors.textPrimary),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase().trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists...',
                    hintStyle:
                        const TextStyle(color: DejaVuColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: DejaVuColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: DejaVuColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: DejaVuColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide:
                          const BorderSide(color: Colors.white24, width: 1),
                    ),
                  ),
                ),
              ),

              // Sort & Status Options Bar
              if (allTracks.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildSortChip(
                        label: 'Title',
                        sortBy: LibrarySortBy.title,
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip(
                        label: 'Artist',
                        sortBy: LibrarySortBy.artist,
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip(
                        label: 'Recently Added',
                        sortBy: LibrarySortBy.recentlyAdded,
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip(
                        label: 'Duration',
                        sortBy: LibrarySortBy.duration,
                      ),
                      if (downloadingCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Downloading ($downloadingCount)',
                          isSelected:
                              _statusFilter == DownloadStatus.downloading,
                          onTap: () => setState(() => _statusFilter =
                              _statusFilter == DownloadStatus.downloading
                                  ? null
                                  : DownloadStatus.downloading),
                        ),
                      ],
                      if (failedCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Failed ($failedCount)',
                          isSelected:
                              _statusFilter == DownloadStatus.failed,
                          color: Colors.redAccent,
                          onTap: () => setState(() => _statusFilter =
                              _statusFilter == DownloadStatus.failed
                                  ? null
                                  : DownloadStatus.failed),
                        ),
                      ],
                    ],
                  ),
                ),

              // Track List
              Expanded(
                child: tracksAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: DejaVuColors.accent),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Error loading library: $err',
                      style: const TextStyle(color: DejaVuColors.textSecondary),
                    ),
                  ),
                  data: (_) => filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No downloaded songs yet. Add a YouTube playlist!'
                                : 'No songs matching "$_searchQuery"',
                            style: const TextStyle(
                                color: DejaVuColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final track = filtered[index];
                            final isCurrentTrack =
                                currentPlayingTrackId == track.id;
                            final isCompleted = track.downloadStatus ==
                                DownloadStatus.completed;
                            final isDownloading = track.downloadStatus ==
                                    DownloadStatus.downloading ||
                                track.downloadStatus ==
                                    DownloadStatus.converting;
                            final isFailed = track.downloadStatus ==
                                DownloadStatus.failed;

                            return ModernTrackTile(
                              track: track,
                              isPlaying: isCurrentTrack,
                              onTap: () {
                                if (isCompleted) {
                                  ref
                                      .read(audioPlayerControllerProvider
                                          .notifier)
                                      .playTrack(
                                        track,
                                        contextTracks: filtered,
                                      );
                                } else if (isDownloading) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Downloading "${track.title}"... Please wait.'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else if (isFailed) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Download failed for "${track.title}". Re-sync its playlist to retry.'),
                                      duration: const Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '"${track.title}" is queued for download.'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              onMoreTap: () =>
                                  _showTrackMenu(context, ref, track),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
  }

  void _showTrackMenu(BuildContext context, WidgetRef ref, Track track) {
    final db = ref.read(appDatabaseProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: DejaVuColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DejaVuColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DejaVuColors.textSecondary),
                ),
              ),
              const Divider(color: Colors.white10),
              if (track.youtubeVideoId != null)
                ListTile(
                  leading: const Icon(Icons.sync_rounded,
                      color: DejaVuColors.accent),
                  title: const Text('Resync Song',
                      style: TextStyle(color: DejaVuColors.textPrimary)),
                  subtitle: const Text(
                      'Re-download audio, refresh artwork & lyrics',
                      style: TextStyle(
                          color: DejaVuColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(syncControllerProvider.notifier)
                        .resyncTrack(track.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Resyncing "${track.title}"...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Delete from Device',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: DejaVuColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Delete Song',
                          style: TextStyle(color: DejaVuColors.textPrimary)),
                      content: Text(
                        'Are you sure you want to permanently delete "${track.title}" from your phone?',
                        style:
                            const TextStyle(color: DejaVuColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: DejaVuColors.textSecondary)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final playerNotifier =
                        ref.read(audioPlayerControllerProvider.notifier);
                    final playerState = ref.read(audioPlayerControllerProvider);
                    final isCurrentTrack =
                        playerState.currentTrack?.id == track.id;
                    await db.deleteTrack(track.id);
                    if (isCurrentTrack) {
                      await playerNotifier.stopAndClear();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required LibrarySortBy sortBy,
  }) {
    final isSelected = _sortBy == sortBy;
    const activeColor = DejaVuColors.accent;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = sortBy;
            // Default to ascending for text (Title, Artist), descending for Date Added and Duration
            _sortAscending = (sortBy == LibrarySortBy.title ||
                sortBy == LibrarySortBy.artist);
          }
        });
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : DejaVuColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : DejaVuColors.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                color: activeColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? DejaVuColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : DejaVuColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : DejaVuColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
