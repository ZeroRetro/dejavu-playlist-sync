import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../../core/database/app_database.dart';
import '../../core/utils/audio_native_utils.dart';
import '../../core/utils/file_utils.dart';

/// Represents real-time sync progress for a specific playlist
class PlaylistSyncState {
  final String playlistId;
  final bool isSyncing;
  final int totalToDownload;
  final int completedDownloads;
  final String? currentTrackTitle;
  final String? errorMessage;

  const PlaylistSyncState({
    required this.playlistId,
    this.isSyncing = false,
    this.totalToDownload = 0,
    this.completedDownloads = 0,
    this.currentTrackTitle,
    this.errorMessage,
  });

  double get progress =>
      totalToDownload == 0 ? 0.0 : completedDownloads / totalToDownload;

  PlaylistSyncState copyWith({
    bool? isSyncing,
    int? totalToDownload,
    int? completedDownloads,
    String? currentTrackTitle,
    String? errorMessage,
  }) {
    return PlaylistSyncState(
      playlistId: playlistId,
      isSyncing: isSyncing ?? this.isSyncing,
      totalToDownload: totalToDownload ?? this.totalToDownload,
      completedDownloads: completedDownloads ?? this.completedDownloads,
      currentTrackTitle: currentTrackTitle,
      errorMessage: errorMessage,
    );
  }
}

class _RawPlaylistItem {
  final String id;
  final String title;
  final String author;
  final Duration duration;

  _RawPlaylistItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
  });
}

class _PlaylistFetchResult {
  final String? title;
  final List<_RawPlaylistItem> videos;

  _PlaylistFetchResult({this.title, required this.videos});
}

class YoutubeSyncService {
  final AppDatabase _db;
  final Dio _dio;
  final _uuid = const Uuid();
  final _activeSyncs = <String>{};

  YoutubeSyncService(this._db, this._dio);

  /// Returns true if a sync operation is currently active for [playlistId]
  bool isSyncing(String playlistId) => _activeSyncs.contains(playlistId);

  /// Sanitizes messy YouTube titles and auto-generated channel authors into clean Artist & Title tags.
  static ({String title, String artist}) cleanTitleAndArtist({
    required String rawTitle,
    required String rawAuthor,
  }) {
    // 1. Strip auto-generated music channel suffix " - Topic"
    var author = rawAuthor
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();

    // 2. Remove common bracketed/parenthesized video metadata tags
    final tagRegex = RegExp(
      r'[\(\[\{]\s*(?:official\s+(?:music\s+)?video|official\s+audio|official\s+hd|official\s+lyric\s+video|official|lyrics?|visualizer|audio|hd|4k(?:\s+remaster)?|video\s+clip|clip\s+officiel|music\s+video|remastered(?:\s+\d{4})?)\s*[\)\]\}]',
      caseSensitive: false,
    );
    var title = rawTitle.replaceAll(tagRegex, '').trim();

    // 3. Remove trailing pipe descriptions like "Title | Official Music Video"
    title = title.replaceAll(RegExp(r'\s*\|\s*.*$'), '').trim();

    // 4. If title contains "Artist - Title", cleanly split into separate components
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        final suspectedArtist = parts[0].trim();
        final suspectedTitle = parts.sublist(1).join(' - ').trim();
        if (suspectedArtist.isNotEmpty && suspectedTitle.isNotEmpty) {
          if (author.isEmpty ||
              author == 'Unknown' ||
              author.toLowerCase() == suspectedArtist.toLowerCase() ||
              rawAuthor.toLowerCase().contains('records') ||
              rawAuthor.toLowerCase().contains('vevo')) {
            author = suspectedArtist;
            title = suspectedTitle;
          }
        }
      }
    }

    if (author.isEmpty) author = 'Unknown';
    if (title.isEmpty) title = rawTitle;

    return (title: title, artist: author);
  }

  /// Creates and immediately syncs a YouTube Playlist from its URL or ID
  Future<String> createAndSyncYoutubePlaylist({
    required String playlistUrlOrId,
    bool convertToMp3 = false,
    required bool deleteOrphanedFiles,
    required void Function(PlaylistSyncState) onStateChanged,
  }) async {
    final ytClient = yt.YoutubeExplode();
    try {
      final parsedId = yt.PlaylistId.parsePlaylistId(playlistUrlOrId);
      if (parsedId == null) {
        throw ArgumentError('Invalid YouTube Playlist URL or ID.');
      }

      final existing = await _db.getPlaylistByYoutubeId(parsedId);
      final internalId = existing?.id ?? _uuid.v4();

      if (existing == null) {
        String playlistTitle = 'YouTube Playlist';
        try {
          final remotePlaylist =
              await ytClient.playlists.get(yt.PlaylistId(parsedId));
          playlistTitle = remotePlaylist.title;
        } catch (e) {
          debugPrint('Could not fetch playlist title via API: $e');
        }

        await _db.createPlaylist(
          PlaylistsCompanion.insert(
            id: internalId,
            name: playlistTitle,
            isYoutubeSynced: const Value(true),
            youtubePlaylistId: Value(parsedId),
            youtubePlaylistUrl:
                Value('https://www.youtube.com/playlist?list=$parsedId'),
          ),
        );
      }

      await syncPlaylist(
        playlistId: internalId,
        convertToMp3: convertToMp3,
        deleteOrphanedFiles: deleteOrphanedFiles,
        onStateChanged: onStateChanged,
      );

      return internalId;
    } finally {
      ytClient.close();
    }
  }

  /// Extracts videos using standard API with fallback to web parsing for newer YouTube layout
  Future<_PlaylistFetchResult> _fetchPlaylistVideos(
      yt.YoutubeExplode ytClient, String playlistId) async {
    final result = <_RawPlaylistItem>[];
    String? playlistTitle;

    try {
      final ytPlaylistId = yt.PlaylistId(playlistId);
      final standardVideos =
          await ytClient.playlists.getVideos(ytPlaylistId).toList();
      if (standardVideos.isNotEmpty) {
        for (final v in standardVideos) {
          final cleaned = cleanTitleAndArtist(
            rawTitle: v.title,
            rawAuthor: v.author,
          );
          result.add(
            _RawPlaylistItem(
              id: v.id.value,
              title: cleaned.title,
              author: cleaned.artist,
              duration: v.duration ?? Duration.zero,
            ),
          );
        }
        return _PlaylistFetchResult(videos: result);
      }
    } catch (_) {}

    // Resilient fallback parser for lockupViewModel
    try {
      final response = await _dio.get(
        'https://www.youtube.com/playlist?list=$playlistId',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );

      final html = response.data.toString();
      final titleMatch = RegExp(r'<meta property="og:title" content="(.*?)">').firstMatch(html) ??
                         RegExp(r'<title>(.*?) - YouTube</title>').firstMatch(html);
      if (titleMatch != null) {
        playlistTitle = titleMatch.group(1);
      }

      final regex = RegExp(r'var ytInitialData = (\{.*?\});<\/script>');
      final match = regex.firstMatch(html);
      if (match != null) {
        final dynamic data = jsonDecode(match.group(1)!);
        void searchLockups(dynamic obj) {
          if (obj is Map) {
            if (obj.containsKey('lockupViewModel')) {
              final lum = obj['lockupViewModel'] as Map;
              final meta = lum['metadata']?['lockupMetadataViewModel'] as Map?;
              final title = meta?['title']?['content']?.toString() ?? 'Unknown';

              String author = 'Unknown';
              final contentMeta =
                  meta?['metadata']?['contentMetadataViewModel'] as Map?;
              final rows = contentMeta?['metadataRows'] as List?;
              if (rows != null && rows.isNotEmpty) {
                final parts = rows[0]['metadataParts'] as List?;
                if (parts != null && parts.isNotEmpty) {
                  final textContent = parts[0]['text']?['content']?.toString();
                  if (textContent != null && textContent.isNotEmpty) {
                    author = textContent;
                  }
                }
              }
              if (author == 'Unknown') {
                final a11y = meta?['image']?['decoratedAvatarViewModel']
                        ?['a11yLabel']
                    ?.toString();
                if (a11y != null && a11y.startsWith('Go to channel ')) {
                  author = a11y.replaceFirst('Go to channel ', '');
                }
              }

              Duration duration = Duration.zero;
              void findBadge(dynamic b) {
                if (duration != Duration.zero) return;
                if (b is Map) {
                  if (b.containsKey('thumbnailBadgeViewModel')) {
                    final txt =
                        b['thumbnailBadgeViewModel']?['text']?.toString() ?? '';
                    if (txt.contains(':')) {
                      final pieces = txt.split(':');
                      if (pieces.length == 2) {
                        duration = Duration(
                          minutes: int.tryParse(pieces[0]) ?? 0,
                          seconds: int.tryParse(pieces[1]) ?? 0,
                        );
                      } else if (pieces.length == 3) {
                        duration = Duration(
                          hours: int.tryParse(pieces[0]) ?? 0,
                          minutes: int.tryParse(pieces[1]) ?? 0,
                          seconds: int.tryParse(pieces[2]) ?? 0,
                        );
                      }
                    }
                  }
                  b.values.forEach(findBadge);
                } else if (b is List) {
                  b.forEach(findBadge);
                }
              }

              findBadge(lum['contentImage']);

              // Fast-path ID extraction avoiding heavy recursive JSON string serialization
              String? vidId;
              final rawContentId = lum['contentId'];
              if (rawContentId is String && rawContentId.length == 11) {
                vidId = rawContentId;
              } else {
                final onTapStr = lum['onTap']?.toString() ?? '';
                final idMatch =
                    RegExp(r'/watch\?v=([a-zA-Z0-9_-]{11})').firstMatch(onTapStr) ??
                        RegExp(r'vi/([a-zA-Z0-9_-]{11})/').firstMatch(onTapStr);
                if (idMatch != null) {
                  vidId = idMatch.group(1);
                } else {
                  final imgStr = lum['contentImage']?.toString() ?? '';
                  final imgMatch =
                      RegExp(r'vi/([a-zA-Z0-9_-]{11})/').firstMatch(imgStr) ??
                          RegExp(r'/watch\?v=([a-zA-Z0-9_-]{11})').firstMatch(imgStr);
                  if (imgMatch != null) {
                    vidId = imgMatch.group(1);
                  }
                }
              }

              if (vidId != null) {
                final cleaned = cleanTitleAndArtist(
                  rawTitle: title,
                  rawAuthor: author,
                );
                result.add(
                  _RawPlaylistItem(
                    id: vidId,
                    title: cleaned.title,
                    author: cleaned.artist,
                    duration: duration,
                  ),
                );
              }
            }
            obj.values.forEach(searchLockups);
          } else if (obj is List) {
            obj.forEach(searchLockups);
          }
        }

        searchLockups(data);
      }
    } catch (e) {
      debugPrint('Fallback parser error: $e');
    }

    return _PlaylistFetchResult(title: playlistTitle, videos: result);
  }

  /// Executes a full Delta Sync for an existing YouTube-linked playlist
  Future<void> syncPlaylist({
    required String playlistId,
    bool convertToMp3 = false,
    bool deleteOrphanedFiles = false,
    required void Function(PlaylistSyncState) onStateChanged,
  }) async {
    final playlist = await _db.getPlaylistById(playlistId);
    if (playlist == null ||
        !playlist.isYoutubeSynced ||
        playlist.youtubePlaylistId == null) {
      throw StateError('Playlist is not configured for YouTube sync.');
    }

    if (_activeSyncs.contains(playlistId)) {
      debugPrint(
          'Sync already in progress for playlist $playlistId, ignoring concurrent invocation.');
      return;
    }
    _activeSyncs.add(playlistId);

    onStateChanged(PlaylistSyncState(
      playlistId: playlistId,
      isSyncing: true,
      currentTrackTitle: 'Fetching YouTube playlist metadata...',
    ));

    final ytClient = yt.YoutubeExplode();
    try {
      // 1. Fetch remote metadata & video list from YouTube
      final ytPlaylistId = yt.PlaylistId(playlist.youtubePlaylistId!);
      String playlistTitle = playlist.name;
      try {
        final remoteMeta = await ytClient.playlists.get(ytPlaylistId);
        playlistTitle = remoteMeta.title;
      } catch (e) {
        debugPrint('Could not fetch remote playlist metadata via API: $e');
      }

      final fetchResult =
          await _fetchPlaylistVideos(ytClient, playlist.youtubePlaylistId!);
      final remoteVideos = fetchResult.videos;

      if (fetchResult.title != null &&
          fetchResult.title!.isNotEmpty &&
          (playlistTitle == 'YouTube Playlist' || playlistTitle.isEmpty)) {
        playlistTitle = fetchResult.title!;
      }

      // 2. Fetch currently linked tracks in local DB
      final currentLocalTracks = await _db.getTracksInPlaylist(playlistId);
      final remoteVideoIds = remoteVideos.map((v) => v.id).toSet();

      // 3. Handle tracks that are no longer returned in the remote playlist
      for (final localTrack in currentLocalTracks) {
        final ytId = localTrack.youtubeVideoId;
        if (ytId != null && !remoteVideoIds.contains(ytId)) {
          // Check if this track is already downloaded locally
          final isDownloaded =
              localTrack.downloadStatus == DownloadStatus.completed &&
                  localTrack.localFilePath != null &&
                  await File(localTrack.localFilePath!).exists();

          if (isDownloaded) {
            // Check if the video still exists as an active public/unlisted video on YouTube
            bool videoStillExistsOnYouTube = false;
            try {
              await ytClient.videos.get(yt.VideoId(ytId));
              videoStillExistsOnYouTube = true;
            } catch (_) {
              // Video was deleted, terminated, privated, or removed from YouTube
              videoStillExistsOnYouTube = false;
            }

            if (!videoStillExistsOnYouTube) {
              // The song was removed/hidden by YouTube, but the user has already downloaded it.
              // Preserve the song in the playlist so offline playback and .m3u8 stay intact!
              debugPrint(
                  'Preserving downloaded track "${localTrack.title}" ($ytId) which was removed/hidden from YouTube.');
              continue;
            }
          }

          // The video is still active on YouTube, meaning it was intentionally removed from this playlist
          await _db.unlinkTrackFromPlaylist(
            playlistId: playlistId,
            trackId: localTrack.id,
          );
        }
      }

      // 4. Identify tracks to link vs tracks that need downloading
      final downloadQueue = <_PendingDownloadTask>[];
      final appDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory(p.join(appDir.path, 'dejavu_thumbs'));
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      // Auto-heal missing cover art, missing lyrics, or corrupted audio on existing tracks
      for (final item in remoteVideos) {
        final track = await _db.getTrackByYoutubeId(item.id);
        if (track != null && track.downloadStatus == DownloadStatus.completed) {
          final isAudioValid = track.localFilePath != null &&
              await File(track.localFilePath!).exists() &&
              await File(track.localFilePath!).length() >= 50 * 1024;

          if (!isAudioValid) {
            // Re-download corrupted or 0-byte track
            downloadQueue.add(
              _PendingDownloadTask(
                trackId: track.id,
                videoId: item.id,
                title: item.title,
                author: item.author,
                duration: item.duration,
              ),
            );
            continue;
          }

          final thumbMissing = track.thumbnailPath == null ||
              !await File(track.thumbnailPath!).exists();
          final lyricsMissing =
              track.lyricsLrc == null || track.lyricsLrc!.isEmpty;

          if (thumbMissing || lyricsMissing) {
            String? healedThumb = track.thumbnailPath;
            String? healedLyrics = track.lyricsLrc;

            if (thumbMissing) {
              healedThumb = await _downloadThumbnailWithFallback(
                videoId: item.id,
                trackId: track.id,
                thumbDir: thumbDir,
              );
            }
            if (lyricsMissing) {
              final cleaned = cleanTitleAndArtist(
                rawTitle: track.title,
                rawAuthor: track.artist,
              );
              healedLyrics = await _fetchLyrics(
                ytClient: ytClient,
                videoId: item.id,
                title: cleaned.title,
                artist: cleaned.artist,
                duration: Duration(milliseconds: track.durationMs),
              );
            }

            if (healedThumb != track.thumbnailPath ||
                healedLyrics != track.lyricsLrc) {
              await (_db.update(_db.tracks)..where((t) => t.id.equals(track.id)))
                  .write(
                TracksCompanion(
                  thumbnailPath: Value(healedThumb),
                  lyricsLrc: Value(healedLyrics),
                ),
              );
            }
          }
        }
      }

      for (var index = 0; index < remoteVideos.length; index++) {
        final item = remoteVideos[index];
        final existingTrack = await _db.getTrackByYoutubeId(item.id);

        if (existingTrack != null) {
          // Update track metadata if remote has better information (artist or duration)
          final needsMetadataUpdate =
              (existingTrack.artist == 'Unknown' && item.author != 'Unknown') ||
                  (existingTrack.durationMs == 0 &&
                      item.duration > Duration.zero) ||
                  existingTrack.title != item.title;

          if (needsMetadataUpdate) {
            await (_db.update(_db.tracks)
                  ..where((t) => t.id.equals(existingTrack.id)))
                .write(
              TracksCompanion(
                title: Value(item.title),
                artist: Value(item.author != 'Unknown'
                    ? item.author
                    : existingTrack.artist),
                durationMs: Value(item.duration > Duration.zero
                    ? item.duration.inMilliseconds
                    : existingTrack.durationMs),
              ),
            );
          }

          // Link immediately and update its position in the playlist
          await _db.linkTrackToPlaylist(
            playlistId: playlistId,
            trackId: existingTrack.id,
            position: index,
          );

          // Queue for download if previous attempt didn't finish or local file is missing/corrupted
          final localFile = existingTrack.localFilePath != null
              ? File(existingTrack.localFilePath!)
              : null;
          final isFileValid = localFile != null &&
              await localFile.exists() &&
              await localFile.length() >= 50 * 1024;

          if (existingTrack.downloadStatus != DownloadStatus.completed ||
              !isFileValid) {
            downloadQueue.add(
              _PendingDownloadTask(
                trackId: existingTrack.id,
                videoId: item.id,
                title: item.title,
                author: item.author,
                duration: item.duration,
              ),
            );
          }
        } else {
          // Brand new track: create DB entry and link to playlist
          final newTrackId = _uuid.v4();
          await _db.upsertTrack(
            TracksCompanion.insert(
              id: newTrackId,
              youtubeVideoId: Value(item.id),
              title: item.title,
              artist: item.author,
              durationMs: Value(item.duration.inMilliseconds),
              downloadStatus: const Value(DownloadStatus.pending),
            ),
          );

          await _db.linkTrackToPlaylist(
            playlistId: playlistId,
            trackId: newTrackId,
            position: index,
          );

          downloadQueue.add(
            _PendingDownloadTask(
              trackId: newTrackId,
              videoId: item.id,
              title: item.title,
              author: item.author,
              duration: item.duration,
            ),
          );
        }
      }

      // 5. Process downloads sequentially (concurrency: 1) with retries for rock-solid stability
      int completedCount = 0;
      onStateChanged(PlaylistSyncState(
        playlistId: playlistId,
        isSyncing: true,
        totalToDownload: downloadQueue.length,
        completedDownloads: 0,
        currentTrackTitle: downloadQueue.isEmpty
            ? 'Playlist already up to date'
            : downloadQueue.first.title,
      ));

      for (var i = 0; i < downloadQueue.length; i++) {
        final task = downloadQueue[i];

        // Jitter delay between sequential track downloads to prevent YouTube 429/403 bot throttling
        if (i > 0) {
          final jitterMs = 800 + Random().nextInt(1200);
          await Future.delayed(Duration(milliseconds: jitterMs));
        }

        await _downloadAndProcessTrack(
          ytClient: ytClient,
          task: task,
        );
        completedCount++;
        onStateChanged(PlaylistSyncState(
          playlistId: playlistId,
          isSyncing: true,
          totalToDownload: downloadQueue.length,
          completedDownloads: completedCount,
          currentTrackTitle: task.title,
        ));
      }

      // 6. Clean up orphaned files if the user enabled auto-cleanup
      if (deleteOrphanedFiles) {
        await _db.pruneOrphanedTracks(deleteLocalFiles: true);
      }

      // 7. Update playlist cover art (from first available track) and sync timestamp
      final updatedTracks = await _db.getTracksInPlaylist(playlistId);
      String? firstThumb;
      for (final t in updatedTracks) {
        if (t.thumbnailPath != null && await File(t.thumbnailPath!).exists()) {
          firstThumb = t.thumbnailPath;
          break;
        }
      }
      firstThumb ??= playlist.thumbnailPath;

      await _db.updatePlaylistSyncMetadata(
        playlistId: playlistId,
        name: playlistTitle,
        thumbnailPath: firstThumb,
        syncedAt: DateTime.now(),
      );

      // 8. Generate & update M3U8 manifest file for external player compatibility
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final audioDir = Directory(p.join(appDir.path, 'dejavu_audio'));
        await FileUtils.writeM3U8File(
          targetDir: audioDir,
          playlistName: playlistTitle,
          tracks: updatedTracks
              .where((t) => t.downloadStatus == DownloadStatus.completed)
              .toList(),
        );
      } catch (m3u8Err) {
        debugPrint('M3U8 generation notice: $m3u8Err');
      }

      onStateChanged(PlaylistSyncState(
        playlistId: playlistId,
        isSyncing: false,
        totalToDownload: downloadQueue.length,
        completedDownloads: completedCount,
      ));
    } catch (e) {
      debugPrint('syncPlaylist fatal error: $e');
      onStateChanged(PlaylistSyncState(
        playlistId: playlistId,
        isSyncing: false,
        errorMessage: e.toString(),
      ));
      rethrow;
    } finally {
      _activeSyncs.remove(playlistId);
      ytClient.close();
    }
  }

  /// Downloads the native AAC/M4A audio stream and caches artwork
  Future<void> _downloadAndProcessTrack({
    required yt.YoutubeExplode ytClient,
    required _PendingDownloadTask task,
  }) async {
    try {
      await _db.updateTrackDownloadState(
        trackId: task.trackId,
        status: DownloadStatus.downloading,
      );

      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(p.join(appDir.path, 'dejavu_audio'));
      final thumbDir = Directory(p.join(appDir.path, 'dejavu_thumbs'));

      if (!await audioDir.exists()) await audioDir.create(recursive: true);
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      // 1. Download stream with multi-attempt retry, fresh manifest, and clean socket closure
      int attempts = 0;
      bool downloaded = false;
      String? finalAudioPath;

      while (attempts < 4 && !downloaded) {
        attempts++;
        try {
          // Fetch stream manifest without WatchPage to avoid 429 rate limit
          final manifest = await ytClient.videos.streamsClient.getManifest(
            task.videoId,
            requireWatchPage: false,
          );

          // 1. Stream selection: prefer pure audio-only stream (AAC itag 140 or Opus itag 251)
          yt.StreamInfo? selectedStream;
          if (manifest.audioOnly.isNotEmpty) {
            final mp4Audio = manifest.audioOnly
                .where((s) => s.container == yt.StreamContainer.mp4)
                .toList();
            selectedStream = mp4Audio.isNotEmpty
                ? mp4Audio.withHighestBitrate()
                : manifest.audioOnly.withHighestBitrate();
          } else if (manifest.muxed.isNotEmpty) {
            selectedStream = manifest.muxed.withHighestBitrate();
          }

          if (selectedStream == null) {
            throw StateError('No playable stream found for ${task.videoId}');
          }

          final isMp4 = selectedStream.container == yt.StreamContainer.mp4;
          final ext = isMp4 ? 'm4a' : 'webm';
          final targetPath = p.join(audioDir.path, '${task.trackId}.$ext');
          finalAudioPath = targetPath;

          final partialFile = File(targetPath);
          if (await partialFile.exists()) {
            await partialFile.delete();
          }

          // Use chunked stream from streamsClient first for rock-solid stability
          try {
            final stream = ytClient.videos.streamsClient.get(selectedStream);
            final output = partialFile.openWrite();
            await stream.pipe(output);
            await output.flush();
            await output.close();
            downloaded = true;
          } catch (streamErr) {
            debugPrint('streamsClient stream pipe failed ($streamErr), trying Dio direct download...');
            if (await partialFile.exists()) {
              await partialFile.delete();
            }
            await _dio.download(
              selectedStream.url.toString(),
              targetPath,
              deleteOnError: true,
              options: Options(
                headers: {
                  'User-Agent':
                      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
                  'Connection': 'close',
                },
                receiveTimeout: const Duration(seconds: 45),
                sendTimeout: const Duration(seconds: 45),
              ),
            );
            downloaded = true;
          }

          // Strict validation: audio file must exist and be >= 50KB to be playable
          final verifiedFile = File(targetPath);
          if (!await verifiedFile.exists() || await verifiedFile.length() < 50 * 1024) {
            downloaded = false;
            if (await verifiedFile.exists()) await verifiedFile.delete();
            throw StateError('Downloaded audio file is invalid or smaller than 50KB');
          }
        } catch (err) {
          if (attempts >= 4) rethrow;
          debugPrint('Retry $attempts/4 for ${task.title} after error: $err');
          await Future.delayed(Duration(milliseconds: 1000 * attempts));
        }
      }

      // If a muxed stream (with video) was downloaded, strip the video track
      if (finalAudioPath != null && Platform.isAndroid) {
        int introOffsetMs = 0;
        try {
          introOffsetMs = await _fetchSponsorBlockIntroOffset(task.videoId);
        } catch (_) {}

        if (introOffsetMs > 0) {
          try {
            await AudioNativeUtils.stripVideoFromMp4(
              finalAudioPath,
              startOffsetMs: introOffsetMs,
            );
          } catch (stripErr) {
            debugPrint('Audio trim notice: $stripErr');
          }
        }
      }

      // 2. Download high quality thumbnail with fallback and 1:1 square crop
      final savedThumbPath = await _downloadThumbnailWithFallback(
        videoId: task.videoId,
        trackId: task.trackId,
        thumbDir: thumbDir,
      );

      // Clean metadata before fetching lyrics for maximum match rate
      final cleanedMeta = cleanTitleAndArtist(
        rawTitle: task.title,
        rawAuthor: task.author,
      );

      // 3. Fetch synchronized lyrics (YouTube captions or LRCLIB with search fallback)
      final lyrics = await _fetchLyrics(
        ytClient: ytClient,
        videoId: task.videoId,
        title: cleanedMeta.title,
        artist: cleanedMeta.artist,
        duration: task.duration,
      );

      // 4. Update DB track record immediately so all data is ready on first sync
      await (_db.update(_db.tracks)..where((t) => t.id.equals(task.trackId)))
          .write(
        TracksCompanion(
          downloadStatus: const Value(DownloadStatus.completed),
          localFilePath: Value(finalAudioPath),
          thumbnailPath: Value(savedThumbPath),
          lyricsLrc: Value(lyrics),
          title: Value(cleanedMeta.title),
          artist: Value(cleanedMeta.artist.isNotEmpty && cleanedMeta.artist != 'Unknown'
              ? cleanedMeta.artist
              : (task.author.isNotEmpty && task.author != 'Unknown' ? task.author : 'Unknown')),
          durationMs: Value(task.duration.inMilliseconds),
        ),
      );

      // 6. Notify Android MediaStore
      if (finalAudioPath != null) {
        await AudioNativeUtils.scanFile(finalAudioPath);
      }

      debugPrint('Successfully downloaded ${task.title} to $finalAudioPath');
    } catch (e, st) {
      debugPrint('Error downloading track ${task.title} (${task.videoId}): $e\n$st');
      await _db.updateTrackDownloadState(
        trackId: task.trackId,
        status: DownloadStatus.failed,
      );
    }
  }

  /// Losslessly strips video from existing downloaded tracks on the device
  /// to ensure 100% pure audio files and eliminate any video decoder overhead.
  Future<void> optimizeExistingLibrary() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final tracks = await _db.getAllTracks();
      for (final track in tracks) {
        if (track.localFilePath != null &&
            track.downloadStatus == DownloadStatus.completed) {
          final file = File(track.localFilePath!);
          if (file.existsSync()) {
            await AudioNativeUtils.stripVideoFromMp4(track.localFilePath!);
          }
        }
      }
    } catch (e) {
      debugPrint('optimizeExistingLibrary error: $e');
    }
  }

  /// Exports an updated .m3u8 manifest file for a specific playlist
  Future<File?> exportM3U8ForPlaylist(String playlistId) async {
    try {
      final playlist = await _db.getPlaylistById(playlistId);
      if (playlist == null) return null;

      final tracks = await _db.getTracksInPlaylist(playlistId);
      final completedTracks = tracks
          .where((t) => t.downloadStatus == DownloadStatus.completed)
          .toList();

      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(p.join(appDir.path, 'dejavu_audio'));
      return await FileUtils.writeM3U8File(
        targetDir: audioDir,
        playlistName: playlist.name,
        tracks: completedTracks,
      );
    } catch (e) {
      debugPrint('exportM3U8ForPlaylist error: $e');
      return null;
    }
  }

  /// Exports updated .m3u8 manifests for all existing playlists in the library
  Future<void> exportAllM3U8Playlists() async {
    try {
      final playlists = await _db.select(_db.playlists).get();
      for (final p in playlists) {
        await exportM3U8ForPlaylist(p.id);
      }
    } catch (e) {
      debugPrint('exportAllM3U8Playlists error: $e');
    }
  }

  /// Downloads thumbnail trying maxresdefault -> hqdefault -> mqdefault,
  /// and center-crops it into a 1:1 square.
  Future<String?> _downloadThumbnailWithFallback({
    required String videoId,
    required String trackId,
    required Directory thumbDir,
  }) async {
    final candidateUrls = [
      'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
      'https://i.ytimg.com/vi/$videoId/default.jpg',
    ];

    final rawPath = p.join(thumbDir.path, '${trackId}_raw.jpg');
    final croppedPath = p.join(thumbDir.path, '$trackId.jpg');

    for (final url in candidateUrls) {
      try {
        final res = await _dio.download(
          url,
          rawPath,
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
            validateStatus: (status) => status == 200,
          ),
        );
        if (res.statusCode == 200 && await File(rawPath).exists()) {
          final cropped = await AudioNativeUtils.cropThumbnailSquare(
            inputPath: rawPath,
            outputPath: croppedPath,
          );
          if (cropped && await File(croppedPath).exists()) {
            try {
              await File(rawPath).delete();
            } catch (_) {}
            return croppedPath;
          } else {
            final f = File(rawPath);
            if (await File(croppedPath).exists()) {
              await File(croppedPath).delete();
            }
            await f.rename(croppedPath);
            return croppedPath;
          }
        }
      } catch (_) {
        if (await File(rawPath).exists()) {
          try {
            await File(rawPath).delete();
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Fetches synchronized lyrics in LRC format:
  /// 1. First tries YouTube video closed captions (timed text).
  /// 2. If unavailable, falls back to LRCLIB API (lrclib.net).
  Future<String?> _fetchLyrics({
    required yt.YoutubeExplode ytClient,
    required String videoId,
    required String title,
    required String artist,
    required Duration duration,
  }) async {
    // 1. Try YouTube closed captions
    try {
      final manifest = await ytClient.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isNotEmpty) {
        yt.ClosedCaptionTrackInfo? selectedTrack;
        for (final t in manifest.tracks) {
          if (!t.isAutoGenerated) {
            selectedTrack = t;
            break;
          }
        }
        selectedTrack ??= manifest.tracks.first;

        final track = await ytClient.videos.closedCaptions.get(selectedTrack);
        if (track.captions.isNotEmpty) {
          final buffer = StringBuffer();
          for (final c in track.captions) {
            final ms = c.offset.inMilliseconds;
            final min = ms ~/ 60000;
            final sec = (ms % 60000) ~/ 1000;
            final hundredths = (ms % 1000) ~/ 10;
            final minStr = min.toString().padLeft(2, '0');
            final secStr = sec.toString().padLeft(2, '0');
            final hStr = hundredths.toString().padLeft(2, '0');
            final cleanText = c.text.replaceAll('\n', ' ').trim();
            if (cleanText.isNotEmpty) {
              buffer.writeln('[$minStr:$secStr.$hStr] $cleanText');
            }
          }
          final lrc = buffer.toString().trim();
          if (lrc.isNotEmpty) {
            return lrc;
          }
        }
      }
    } catch (_) {}

    // 2. Try LRCLIB exact match API
    try {
      final durationSec = duration.inSeconds;
      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': title,
          if (artist != 'Unknown' && artist.isNotEmpty) 'artist_name': artist,
          if (durationSec > 0) 'duration': durationSec,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final synced = response.data['syncedLyrics']?.toString();
        if (synced != null && synced.trim().isNotEmpty) {
          return synced.trim();
        }
        final plain = response.data['plainLyrics']?.toString();
        if (plain != null && plain.trim().isNotEmpty) {
          return plain.trim();
        }
      }
    } catch (_) {}

    // 3. Fallback to LRCLIB Search API (handles duration drift and title formatting differences)
    try {
      final query = (artist != 'Unknown' && artist.isNotEmpty)
          ? '$artist $title'
          : title;
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': query},
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 &&
          response.data is List &&
          (response.data as List).isNotEmpty) {
        final list = (response.data as List).whereType<Map>().toList();

        // Prefer items with synced lyrics
        final syncedItems = list.where((item) {
          final s = item['syncedLyrics']?.toString();
          return s != null && s.trim().isNotEmpty;
        }).toList();

        if (syncedItems.isNotEmpty) {
          // If duration > 0, pick the candidate closest to track duration
          if (duration.inSeconds > 0) {
            syncedItems.sort((a, b) {
              final durA = (a['duration'] as num?)?.toInt() ?? 0;
              final durB = (b['duration'] as num?)?.toInt() ?? 0;
              final diffA = (durA - duration.inSeconds).abs();
              final diffB = (durB - duration.inSeconds).abs();
              return diffA.compareTo(diffB);
            });
          }
          final chosen = syncedItems.first['syncedLyrics']?.toString();
          if (chosen != null && chosen.trim().isNotEmpty) {
            return chosen.trim();
          }
        }

        // Fallback to plain lyrics if synced not found
        for (final item in list) {
          final plain = item['plainLyrics']?.toString();
          if (plain != null && plain.trim().isNotEmpty) {
            return plain.trim();
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Queries SponsorBlock API for music_offtopic skip segments (intro skits / outro credits).
  Future<int> _fetchSponsorBlockIntroOffset(String videoId) async {
    try {
      final res = await _dio.get(
        'https://sponsor.ajay.app/api/skipSegments',
        queryParameters: {
          'videoID': videoId,
          'category': 'music_offtopic',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (res.statusCode == 200 &&
          res.data is List &&
          (res.data as List).isNotEmpty) {
        for (final item in res.data as List) {
          if (item is Map && item['segment'] is List) {
            final seg = item['segment'] as List;
            if (seg.length >= 2) {
              final startSec = (seg[0] as num).toDouble();
              final endSec = (seg[1] as num).toDouble();
              if (startSec <= 3.0 && endSec > 4.0) {
                return (endSec * 1000).toInt();
              }
            }
          }
        }
      }
    } catch (_) {}
    return 0;
  }
}

class _PendingDownloadTask {
  final String trackId;
  final String videoId;
  final String title;
  final String author;
  final Duration duration;

  _PendingDownloadTask({
    required this.trackId,
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
  });
}

// -----------------------------------------------------------------------------
// RIVERPOD PROVIDERS FOR THE UI
// -----------------------------------------------------------------------------

final dioProvider = Provider<Dio>((ref) => Dio());

final youtubeSyncServiceProvider = Provider<YoutubeSyncService>((ref) {
  return YoutubeSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(dioProvider),
  );
});

/// Holds a map of playlistId -> PlaylistSyncState so the UI can show progress bars
class SyncControllerNotifier
    extends StateNotifier<Map<String, PlaylistSyncState>> {
  final YoutubeSyncService _syncService;

  SyncControllerNotifier(this._syncService) : super(const {});

  Future<void> syncPlaylist(
    String playlistId, {
    bool convertToMp3 = false,
    bool deleteOrphans = false,
  }) async {
    await _syncService.syncPlaylist(
      playlistId: playlistId,
      convertToMp3: convertToMp3,
      deleteOrphanedFiles: deleteOrphans,
      onStateChanged: (syncState) {
        state = {...state, playlistId: syncState};
      },
    );
  }

  Future<String> createAndSync(
    String url, {
    bool convertToMp3 = false,
    bool deleteOrphans = false,
  }) async {
    return _syncService.createAndSyncYoutubePlaylist(
      playlistUrlOrId: url,
      convertToMp3: convertToMp3,
      deleteOrphanedFiles: deleteOrphans,
      onStateChanged: (syncState) {
        state = {...state, syncState.playlistId: syncState};
      },
    );
  }

  Future<void> optimizeExistingLibrary() =>
      _syncService.optimizeExistingLibrary();
}

final syncControllerProvider = StateNotifierProvider<SyncControllerNotifier,
    Map<String, PlaylistSyncState>>((ref) {
  return SyncControllerNotifier(ref.watch(youtubeSyncServiceProvider));
});
