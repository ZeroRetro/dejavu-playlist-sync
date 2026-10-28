import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Track download lifecycle states
enum DownloadStatus {
  pending, // 0
  downloading, // 1
  converting, // 2
  completed, // 3
  failed, // 4
}

/// 1. Stores all downloaded audio files on the device
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get youtubeVideoId => text().nullable().unique()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get localFilePath => text().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get lyricsLrc => text().nullable()();
  IntColumn get downloadStatus =>
      intEnum<DownloadStatus>().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 2. Stores both YouTube-synced and purely local playlists
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isYoutubeSynced =>
      boolean().withDefault(const Constant(false))();
  TextColumn get youtubePlaylistId => text().nullable().unique()();
  TextColumn get youtubePlaylistUrl => text().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 3. Many-to-Many join table linking tracks to playlists with ordering
class PlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

/// Helper model combining a Playlist with its live track counts
class PlaylistWithCounts {
  final Playlist playlist;
  final int totalTracks;
  final int downloadedTracks;

  PlaylistWithCounts({
    required this.playlist,
    required this.totalTracks,
    required this.downloadedTracks,
  });
}

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(tracks, tracks.lyricsLrc);
          }
        },
        beforeOpen: (details) async {
          // Enforce SQLite foreign key cascades
          await customStatement('PRAGMA foreign_keys = ON');
          // Enable Write-Ahead Logging (WAL) for concurrent reads/writes without lock contention
          await customStatement('PRAGMA journal_mode = WAL');
          // Normal synchronous mode reduces disk flush overhead on mobile flash storage
          await customStatement('PRAGMA synchronous = NORMAL');
          // Keep temporary tables and indices in RAM
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );

  // ---------------------------------------------------------------------------
  // PLAYLIST QUERIES
  // ---------------------------------------------------------------------------

  /// Watch all playlists along with total and completed track counts
  Stream<List<PlaylistWithCounts>> watchPlaylistsWithCounts() {
    final query = select(playlists).join([
      leftOuterJoin(
        playlistTracks,
        playlistTracks.playlistId.equalsExp(playlists.id),
      ),
      leftOuterJoin(
        tracks,
        tracks.id.equalsExp(playlistTracks.trackId),
      ),
    ]);

    return query.watch().map((rows) {
      final grouped = <String, PlaylistWithCounts>{};
      for (final row in rows) {
        final playlist = row.readTable(playlists);
        final track = row.readTableOrNull(tracks);

        final current = grouped[playlist.id] ??
            PlaylistWithCounts(
              playlist: playlist,
              totalTracks: 0,
              downloadedTracks: 0,
            );

        if (track != null) {
          final isDownloaded = track.downloadStatus == DownloadStatus.completed;
          grouped[playlist.id] = PlaylistWithCounts(
            playlist: playlist,
            totalTracks: current.totalTracks + 1,
            downloadedTracks:
                current.downloadedTracks + (isDownloaded ? 1 : 0),
          );
        } else {
          grouped[playlist.id] = current;
        }
      }
      return grouped.values.toList();
    });
  }

  /// Create a new Local or YouTube-Linked Playlist
  Future<void> createPlaylist(PlaylistsCompanion entry) =>
      into(playlists).insert(entry);

  /// Delete a playlist and cascade unlinks.
  /// If [deleteAudioFiles] is true, deletes audio and thumbnail files on disk
  /// for tracks belonging to this playlist, EXCEPT for tracks that are also used
  /// in other playlists. Also removes the .m3u8 playlist manifest.
  Future<void> deletePlaylist(String playlistId, {bool deleteAudioFiles = false}) async {
    final playlist = await getPlaylistById(playlistId);

    if (deleteAudioFiles) {
      // 1. Find all tracks currently in this playlist
      final playlistTracksList = await getTracksInPlaylist(playlistId);

      // 2. Find all track IDs that belong to any other playlist
      final otherLinkedRows = await (selectOnly(playlistTracks, distinct: true)
            ..addColumns([playlistTracks.trackId])
            ..where(playlistTracks.playlistId.equals(playlistId).not()))
          .get();
      final preservedTrackIds = otherLinkedRows
          .map((r) => r.read(playlistTracks.trackId)!)
          .toSet();

      // 3. Delete files and track rows for tracks not used elsewhere
      for (final track in playlistTracksList) {
        if (!preservedTrackIds.contains(track.id)) {
          if (track.localFilePath != null) {
            final f = File(track.localFilePath!);
            if (await f.exists()) await f.delete();
          }
          if (track.thumbnailPath != null) {
            final f = File(track.thumbnailPath!);
            if (await f.exists()) await f.delete();
          }
          await (delete(tracks)..where((t) => t.id.equals(track.id))).go();
        }
      }
    }

    // 4. Delete the playlist record itself (cascades to playlistTracks join table)
    await (delete(playlists)..where((p) => p.id.equals(playlistId))).go();

    // 5. Delete the .m3u8 manifest file if present
    if (playlist != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final audioDir = Directory(p.join(appDir.path, 'dejavu_audio'));
        final safeName = playlist.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final m3u8File = File(p.join(audioDir.path, '$safeName.m3u8'));
        if (await m3u8File.exists()) {
          await m3u8File.delete();
        }
      } catch (e) {
        // Non-critical cleanup
      }
    }
  }

  /// Get single playlist by ID
  Future<Playlist?> getPlaylistById(String id) =>
      (select(playlists)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Find a playlist by its YouTube playlist ID
  Future<Playlist?> getPlaylistByYoutubeId(String youtubePlaylistId) =>
      (select(playlists)
            ..where((p) => p.youtubePlaylistId.equals(youtubePlaylistId)))
          .getSingleOrNull();

  /// Get all playlists in database
  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  /// Update playlist metadata after sync
  Future<void> updatePlaylistSyncMetadata({
    required String playlistId,
    String? name,
    String? thumbnailPath,
    required DateTime syncedAt,
  }) async {
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        thumbnailPath: thumbnailPath != null
            ? Value(thumbnailPath)
            : const Value.absent(),
        lastSyncedAt: Value(syncedAt),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRACK & LINKING QUERIES
  // ---------------------------------------------------------------------------

  /// Reactive stream of ordered tracks inside a specific playlist
  Stream<List<Track>> watchTracksInPlaylist(String playlistId) {
    final query = (select(playlistTracks)
          ..where((pt) => pt.playlistId.equals(playlistId))
          ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
        .join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ]);

    return query
        .watch()
        .map((rows) => rows.map((row) => row.readTable(tracks)).toList());
  }

  /// Watch all tracks in library
  Stream<List<Track>> watchAllTracks() {
    return (select(tracks)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Lightweight reactive stream of the total completed/downloaded track count
  Stream<int> watchCompletedTracksCount() {
    final count = tracks.id.count();
    final query = selectOnly(tracks)
      ..addColumns([count])
      ..where(tracks.downloadStatus.equals(DownloadStatus.completed.index));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Get all tracks in library
  Future<List<Track>> getAllTracks() => select(tracks).get();

  /// Get single track by ID
  Future<Track?> getTrackById(String id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// One-shot fetch of tracks currently in a playlist (used by Delta Sync)
  Future<List<Track>> getTracksInPlaylist(String playlistId) async {
    final query = (select(playlistTracks)
          ..where((pt) => pt.playlistId.equals(playlistId))
          ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
        .join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(tracks)).toList();
  }

  /// Find if a YouTube video is already in our database from another playlist
  Future<Track?> getTrackByYoutubeId(String youtubeVideoId) =>
      (select(tracks)..where((t) => t.youtubeVideoId.equals(youtubeVideoId)))
          .getSingleOrNull();

  /// Insert or update a track
  Future<void> upsertTrack(TracksCompanion track) =>
      into(tracks).insertOnConflictUpdate(track);

  /// Update download status & file paths for a track
  Future<void> updateTrackDownloadState({
    required String trackId,
    required DownloadStatus status,
    String? localFilePath,
    String? thumbnailPath,
  }) async {
    await (update(tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(
        downloadStatus: Value(status),
        localFilePath: localFilePath != null
            ? Value(localFilePath)
            : const Value.absent(),
        thumbnailPath: thumbnailPath != null
            ? Value(thumbnailPath)
            : const Value.absent(),
      ),
    );
  }

  /// Link a Track (YouTube or Local) to any Playlist without duplicating files
  Future<void> linkTrackToPlaylist({
    required String playlistId,
    required String trackId,
    required int position,
  }) async {
    await into(playlistTracks).insertOnConflictUpdate(
      PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        position: position,
      ),
    );
  }

  /// Unlink a Track from a specific playlist
  Future<void> unlinkTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    await (delete(playlistTracks)
          ..where((pt) =>
              pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
        .go();
  }

  /// Delete a track entirely from database and remove its audio/thumb file
  Future<void> deleteTrack(String trackId) async {
    final track = await (select(tracks)..where((t) => t.id.equals(trackId)))
        .getSingleOrNull();
    if (track != null) {
      if (track.localFilePath != null) {
        final f = File(track.localFilePath!);
        if (await f.exists()) await f.delete();
      }
      if (track.thumbnailPath != null) {
        final f = File(track.thumbnailPath!);
        if (await f.exists()) await f.delete();
      }
      await (delete(tracks)..where((t) => t.id.equals(trackId))).go();
    }
  }

  /// Delete orphaned tracks that do not belong to ANY playlist (Synced or Local)
  Future<int> pruneOrphanedTracks({bool deleteLocalFiles = true}) async {
    final allLinkedIdsQuery = selectOnly(playlistTracks, distinct: true)
      ..addColumns([playlistTracks.trackId]);
    final linkedRows = await allLinkedIdsQuery.get();
    final linkedIds =
        linkedRows.map((r) => r.read(playlistTracks.trackId)!).toSet();

    final allTracks = await select(tracks).get();
    final orphans =
        allTracks.where((t) => !linkedIds.contains(t.id)).toList();

    for (final orphan in orphans) {
      if (deleteLocalFiles) {
        if (orphan.localFilePath != null) {
          final audioFile = File(orphan.localFilePath!);
          if (await audioFile.exists()) await audioFile.delete();
        }
        if (orphan.thumbnailPath != null) {
          final thumbFile = File(orphan.thumbnailPath!);
          if (await thumbFile.exists()) await thumbFile.delete();
        }
      }
      await (delete(tracks)..where((t) => t.id.equals(orphan.id))).go();
    }
    return orphans.length;
  }

  /// Verifies that all completed tracks still exist on disk with valid size (>= 50KB).
  /// If missing or truncated, updates their status to pending so they can be re-synced.
  Future<int> verifyLocalIntegrity() async {
    final completed = await (select(tracks)
          ..where((t) => t.downloadStatus.equals(DownloadStatus.completed.index)))
        .get();

    int fixedCount = 0;
    for (final track in completed) {
      bool isValid = false;
      if (track.localFilePath != null) {
        final f = File(track.localFilePath!);
        if (f.existsSync() && f.lengthSync() >= 50 * 1024) {
          isValid = true;
        }
      }
      if (!isValid) {
        await (update(tracks)..where((t) => t.id.equals(track.id))).write(
          const TracksCompanion(
            downloadStatus: Value(DownloadStatus.pending),
            localFilePath: Value(null),
          ),
        );
        fixedCount++;
      }
    }
    return fixedCount;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dejavu_music.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Global Riverpod Provider for the Database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Cached reactive stream provider for playlists with track counts (prevents stream recreation on rebuild)
final playlistsWithCountsStreamProvider =
    StreamProvider<List<PlaylistWithCounts>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPlaylistsWithCounts();
});

/// Cached reactive stream provider for all tracks in library (prevents query rebuilds while searching)
final allTracksStreamProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllTracks();
});

/// Cached reactive stream provider for tracks inside a specific playlist
final playlistTracksStreamProvider =
    StreamProvider.family<List<Track>, String>((ref, playlistId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchTracksInPlaylist(playlistId);
});
