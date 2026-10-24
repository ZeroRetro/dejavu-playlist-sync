// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _youtubeVideoIdMeta =
      const VerificationMeta('youtubeVideoId');
  @override
  late final GeneratedColumn<String> youtubeVideoId = GeneratedColumn<String>(
      'youtube_video_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lyricsLrcMeta =
      const VerificationMeta('lyricsLrc');
  @override
  late final GeneratedColumn<String> lyricsLrc = GeneratedColumn<String>(
      'lyrics_lrc', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int>
      downloadStatus = GeneratedColumn<int>(
              'download_status', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<DownloadStatus>($TracksTable.$converterdownloadStatus);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        youtubeVideoId,
        title,
        artist,
        durationMs,
        localFilePath,
        thumbnailPath,
        lyricsLrc,
        downloadStatus,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(Insertable<Track> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('youtube_video_id')) {
      context.handle(
          _youtubeVideoIdMeta,
          youtubeVideoId.isAcceptableOrUnknown(
              data['youtube_video_id']!, _youtubeVideoIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('lyrics_lrc')) {
      context.handle(_lyricsLrcMeta,
          lyricsLrc.isAcceptableOrUnknown(data['lyrics_lrc']!, _lyricsLrcMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      youtubeVideoId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}youtube_video_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      localFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_file_path']),
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      lyricsLrc: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lyrics_lrc']),
      downloadStatus: $TracksTable.$converterdownloadStatus.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.int, data['${effectivePrefix}download_status'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatus, int, int> $converterdownloadStatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class Track extends DataClass implements Insertable<Track> {
  final String id;
  final String? youtubeVideoId;
  final String title;
  final String artist;
  final int durationMs;
  final String? localFilePath;
  final String? thumbnailPath;
  final String? lyricsLrc;
  final DownloadStatus downloadStatus;
  final DateTime createdAt;
  const Track(
      {required this.id,
      this.youtubeVideoId,
      required this.title,
      required this.artist,
      required this.durationMs,
      this.localFilePath,
      this.thumbnailPath,
      this.lyricsLrc,
      required this.downloadStatus,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || youtubeVideoId != null) {
      map['youtube_video_id'] = Variable<String>(youtubeVideoId);
    }
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || lyricsLrc != null) {
      map['lyrics_lrc'] = Variable<String>(lyricsLrc);
    }
    {
      map['download_status'] = Variable<int>(
          $TracksTable.$converterdownloadStatus.toSql(downloadStatus));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      youtubeVideoId: youtubeVideoId == null && nullToAbsent
          ? const Value.absent()
          : Value(youtubeVideoId),
      title: Value(title),
      artist: Value(artist),
      durationMs: Value(durationMs),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      lyricsLrc: lyricsLrc == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsLrc),
      downloadStatus: Value(downloadStatus),
      createdAt: Value(createdAt),
    );
  }

  factory Track.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<String>(json['id']),
      youtubeVideoId: serializer.fromJson<String?>(json['youtubeVideoId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      lyricsLrc: serializer.fromJson<String?>(json['lyricsLrc']),
      downloadStatus: $TracksTable.$converterdownloadStatus
          .fromJson(serializer.fromJson<int>(json['downloadStatus'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'youtubeVideoId': serializer.toJson<String?>(youtubeVideoId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'durationMs': serializer.toJson<int>(durationMs),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'lyricsLrc': serializer.toJson<String?>(lyricsLrc),
      'downloadStatus': serializer.toJson<int>(
          $TracksTable.$converterdownloadStatus.toJson(downloadStatus)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Track copyWith(
          {String? id,
          Value<String?> youtubeVideoId = const Value.absent(),
          String? title,
          String? artist,
          int? durationMs,
          Value<String?> localFilePath = const Value.absent(),
          Value<String?> thumbnailPath = const Value.absent(),
          Value<String?> lyricsLrc = const Value.absent(),
          DownloadStatus? downloadStatus,
          DateTime? createdAt}) =>
      Track(
        id: id ?? this.id,
        youtubeVideoId:
            youtubeVideoId.present ? youtubeVideoId.value : this.youtubeVideoId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        durationMs: durationMs ?? this.durationMs,
        localFilePath:
            localFilePath.present ? localFilePath.value : this.localFilePath,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        lyricsLrc: lyricsLrc.present ? lyricsLrc.value : this.lyricsLrc,
        downloadStatus: downloadStatus ?? this.downloadStatus,
        createdAt: createdAt ?? this.createdAt,
      );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      youtubeVideoId: data.youtubeVideoId.present
          ? data.youtubeVideoId.value
          : this.youtubeVideoId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      lyricsLrc: data.lyricsLrc.present ? data.lyricsLrc.value : this.lyricsLrc,
      downloadStatus: data.downloadStatus.present
          ? data.downloadStatus.value
          : this.downloadStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('youtubeVideoId: $youtubeVideoId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationMs: $durationMs, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('lyricsLrc: $lyricsLrc, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, youtubeVideoId, title, artist, durationMs,
      localFilePath, thumbnailPath, lyricsLrc, downloadStatus, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.youtubeVideoId == this.youtubeVideoId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.durationMs == this.durationMs &&
          other.localFilePath == this.localFilePath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.lyricsLrc == this.lyricsLrc &&
          other.downloadStatus == this.downloadStatus &&
          other.createdAt == this.createdAt);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<String> id;
  final Value<String?> youtubeVideoId;
  final Value<String> title;
  final Value<String> artist;
  final Value<int> durationMs;
  final Value<String?> localFilePath;
  final Value<String?> thumbnailPath;
  final Value<String?> lyricsLrc;
  final Value<DownloadStatus> downloadStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.youtubeVideoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.lyricsLrc = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String id,
    this.youtubeVideoId = const Value.absent(),
    required String title,
    required String artist,
    this.durationMs = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.lyricsLrc = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        artist = Value(artist);
  static Insertable<Track> custom({
    Expression<String>? id,
    Expression<String>? youtubeVideoId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<int>? durationMs,
    Expression<String>? localFilePath,
    Expression<String>? thumbnailPath,
    Expression<String>? lyricsLrc,
    Expression<int>? downloadStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (youtubeVideoId != null) 'youtube_video_id': youtubeVideoId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (durationMs != null) 'duration_ms': durationMs,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (lyricsLrc != null) 'lyrics_lrc': lyricsLrc,
      if (downloadStatus != null) 'download_status': downloadStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith(
      {Value<String>? id,
      Value<String?>? youtubeVideoId,
      Value<String>? title,
      Value<String>? artist,
      Value<int>? durationMs,
      Value<String?>? localFilePath,
      Value<String?>? thumbnailPath,
      Value<String?>? lyricsLrc,
      Value<DownloadStatus>? downloadStatus,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return TracksCompanion(
      id: id ?? this.id,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationMs: durationMs ?? this.durationMs,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (youtubeVideoId.present) {
      map['youtube_video_id'] = Variable<String>(youtubeVideoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (lyricsLrc.present) {
      map['lyrics_lrc'] = Variable<String>(lyricsLrc.value);
    }
    if (downloadStatus.present) {
      map['download_status'] = Variable<int>(
          $TracksTable.$converterdownloadStatus.toSql(downloadStatus.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('youtubeVideoId: $youtubeVideoId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationMs: $durationMs, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('lyricsLrc: $lyricsLrc, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isYoutubeSyncedMeta =
      const VerificationMeta('isYoutubeSynced');
  @override
  late final GeneratedColumn<bool> isYoutubeSynced = GeneratedColumn<bool>(
      'is_youtube_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_youtube_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _youtubePlaylistIdMeta =
      const VerificationMeta('youtubePlaylistId');
  @override
  late final GeneratedColumn<String> youtubePlaylistId =
      GeneratedColumn<String>('youtube_playlist_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _youtubePlaylistUrlMeta =
      const VerificationMeta('youtubePlaylistUrl');
  @override
  late final GeneratedColumn<String> youtubePlaylistUrl =
      GeneratedColumn<String>('youtube_playlist_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        isYoutubeSynced,
        youtubePlaylistId,
        youtubePlaylistUrl,
        thumbnailPath,
        lastSyncedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(Insertable<Playlist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_youtube_synced')) {
      context.handle(
          _isYoutubeSyncedMeta,
          isYoutubeSynced.isAcceptableOrUnknown(
              data['is_youtube_synced']!, _isYoutubeSyncedMeta));
    }
    if (data.containsKey('youtube_playlist_id')) {
      context.handle(
          _youtubePlaylistIdMeta,
          youtubePlaylistId.isAcceptableOrUnknown(
              data['youtube_playlist_id']!, _youtubePlaylistIdMeta));
    }
    if (data.containsKey('youtube_playlist_url')) {
      context.handle(
          _youtubePlaylistUrlMeta,
          youtubePlaylistUrl.isAcceptableOrUnknown(
              data['youtube_playlist_url']!, _youtubePlaylistUrlMeta));
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isYoutubeSynced: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_youtube_synced'])!,
      youtubePlaylistId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}youtube_playlist_id']),
      youtubePlaylistUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}youtube_playlist_url']),
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String id;
  final String name;
  final bool isYoutubeSynced;
  final String? youtubePlaylistId;
  final String? youtubePlaylistUrl;
  final String? thumbnailPath;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  const Playlist(
      {required this.id,
      required this.name,
      required this.isYoutubeSynced,
      this.youtubePlaylistId,
      this.youtubePlaylistUrl,
      this.thumbnailPath,
      this.lastSyncedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['is_youtube_synced'] = Variable<bool>(isYoutubeSynced);
    if (!nullToAbsent || youtubePlaylistId != null) {
      map['youtube_playlist_id'] = Variable<String>(youtubePlaylistId);
    }
    if (!nullToAbsent || youtubePlaylistUrl != null) {
      map['youtube_playlist_url'] = Variable<String>(youtubePlaylistUrl);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      isYoutubeSynced: Value(isYoutubeSynced),
      youtubePlaylistId: youtubePlaylistId == null && nullToAbsent
          ? const Value.absent()
          : Value(youtubePlaylistId),
      youtubePlaylistUrl: youtubePlaylistUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(youtubePlaylistUrl),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isYoutubeSynced: serializer.fromJson<bool>(json['isYoutubeSynced']),
      youtubePlaylistId:
          serializer.fromJson<String?>(json['youtubePlaylistId']),
      youtubePlaylistUrl:
          serializer.fromJson<String?>(json['youtubePlaylistUrl']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'isYoutubeSynced': serializer.toJson<bool>(isYoutubeSynced),
      'youtubePlaylistId': serializer.toJson<String?>(youtubePlaylistId),
      'youtubePlaylistUrl': serializer.toJson<String?>(youtubePlaylistUrl),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Playlist copyWith(
          {String? id,
          String? name,
          bool? isYoutubeSynced,
          Value<String?> youtubePlaylistId = const Value.absent(),
          Value<String?> youtubePlaylistUrl = const Value.absent(),
          Value<String?> thumbnailPath = const Value.absent(),
          Value<DateTime?> lastSyncedAt = const Value.absent(),
          DateTime? createdAt}) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        isYoutubeSynced: isYoutubeSynced ?? this.isYoutubeSynced,
        youtubePlaylistId: youtubePlaylistId.present
            ? youtubePlaylistId.value
            : this.youtubePlaylistId,
        youtubePlaylistUrl: youtubePlaylistUrl.present
            ? youtubePlaylistUrl.value
            : this.youtubePlaylistUrl,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isYoutubeSynced: data.isYoutubeSynced.present
          ? data.isYoutubeSynced.value
          : this.isYoutubeSynced,
      youtubePlaylistId: data.youtubePlaylistId.present
          ? data.youtubePlaylistId.value
          : this.youtubePlaylistId,
      youtubePlaylistUrl: data.youtubePlaylistUrl.present
          ? data.youtubePlaylistUrl.value
          : this.youtubePlaylistUrl,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isYoutubeSynced: $isYoutubeSynced, ')
          ..write('youtubePlaylistId: $youtubePlaylistId, ')
          ..write('youtubePlaylistUrl: $youtubePlaylistUrl, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isYoutubeSynced, youtubePlaylistId,
      youtubePlaylistUrl, thumbnailPath, lastSyncedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.isYoutubeSynced == this.isYoutubeSynced &&
          other.youtubePlaylistId == this.youtubePlaylistId &&
          other.youtubePlaylistUrl == this.youtubePlaylistUrl &&
          other.thumbnailPath == this.thumbnailPath &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> isYoutubeSynced;
  final Value<String?> youtubePlaylistId;
  final Value<String?> youtubePlaylistUrl;
  final Value<String?> thumbnailPath;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isYoutubeSynced = const Value.absent(),
    this.youtubePlaylistId = const Value.absent(),
    this.youtubePlaylistUrl = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    this.isYoutubeSynced = const Value.absent(),
    this.youtubePlaylistId = const Value.absent(),
    this.youtubePlaylistUrl = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Playlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? isYoutubeSynced,
    Expression<String>? youtubePlaylistId,
    Expression<String>? youtubePlaylistUrl,
    Expression<String>? thumbnailPath,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isYoutubeSynced != null) 'is_youtube_synced': isYoutubeSynced,
      if (youtubePlaylistId != null) 'youtube_playlist_id': youtubePlaylistId,
      if (youtubePlaylistUrl != null)
        'youtube_playlist_url': youtubePlaylistUrl,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<bool>? isYoutubeSynced,
      Value<String?>? youtubePlaylistId,
      Value<String?>? youtubePlaylistUrl,
      Value<String?>? thumbnailPath,
      Value<DateTime?>? lastSyncedAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isYoutubeSynced: isYoutubeSynced ?? this.isYoutubeSynced,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
      youtubePlaylistUrl: youtubePlaylistUrl ?? this.youtubePlaylistUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isYoutubeSynced.present) {
      map['is_youtube_synced'] = Variable<bool>(isYoutubeSynced.value);
    }
    if (youtubePlaylistId.present) {
      map['youtube_playlist_id'] = Variable<String>(youtubePlaylistId.value);
    }
    if (youtubePlaylistUrl.present) {
      map['youtube_playlist_url'] = Variable<String>(youtubePlaylistUrl.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isYoutubeSynced: $isYoutubeSynced, ')
          ..write('youtubePlaylistId: $youtubePlaylistId, ')
          ..write('youtubePlaylistUrl: $youtubePlaylistUrl, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES playlists (id) ON DELETE CASCADE'));
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE CASCADE'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [playlistId, trackId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistTrack> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackId};
  @override
  PlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrack(
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrack extends DataClass implements Insertable<PlaylistTrack> {
  final String playlistId;
  final String trackId;
  final int position;
  const PlaylistTrack(
      {required this.playlistId,
      required this.trackId,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['track_id'] = Variable<String>(trackId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
    );
  }

  factory PlaylistTrack.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrack(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'trackId': serializer.toJson<String>(trackId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistTrack copyWith(
          {String? playlistId, String? trackId, int? position}) =>
      PlaylistTrack(
        playlistId: playlistId ?? this.playlistId,
        trackId: trackId ?? this.trackId,
        position: position ?? this.position,
      );
  PlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrack(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrack> {
  final Value<String> playlistId;
  final Value<String> trackId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    required String playlistId,
    required String trackId,
    required int position,
    this.rowid = const Value.absent(),
  })  : playlistId = Value(playlistId),
        trackId = Value(trackId),
        position = Value(position);
  static Insertable<PlaylistTrack> custom({
    Expression<String>? playlistId,
    Expression<String>? trackId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksCompanion copyWith(
      {Value<String>? playlistId,
      Value<String>? trackId,
      Value<int>? position,
      Value<int>? rowid}) {
    return PlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [tracks, playlists, playlistTracks];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('playlists',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_tracks', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_tracks', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  required String id,
  Value<String?> youtubeVideoId,
  required String title,
  required String artist,
  Value<int> durationMs,
  Value<String?> localFilePath,
  Value<String?> thumbnailPath,
  Value<String?> lyricsLrc,
  Value<DownloadStatus> downloadStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<String> id,
  Value<String?> youtubeVideoId,
  Value<String> title,
  Value<String> artist,
  Value<int> durationMs,
  Value<String?> localFilePath,
  Value<String?> thumbnailPath,
  Value<String?> lyricsLrc,
  Value<DownloadStatus> downloadStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
      _playlistTracksRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistTracks,
              aliasName: 'tracks__id__playlist_tracks__track_id');

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager($_db, $_db.playlistTracks)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get youtubeVideoId => $composableBuilder(
      column: $table.youtubeVideoId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lyricsLrc => $composableBuilder(
      column: $table.lyricsLrc, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
      get downloadStatus => $composableBuilder(
          column: $table.downloadStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> playlistTracksRefs(
      Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableFilterComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get youtubeVideoId => $composableBuilder(
      column: $table.youtubeVideoId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lyricsLrc => $composableBuilder(
      column: $table.lyricsLrc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get downloadStatus => $composableBuilder(
      column: $table.downloadStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get youtubeVideoId => $composableBuilder(
      column: $table.youtubeVideoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<String> get lyricsLrc =>
      $composableBuilder(column: $table.lyricsLrc, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get downloadStatus =>
      $composableBuilder(
          column: $table.downloadStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
      Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TracksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TracksTable,
    Track,
    $$TracksTableFilterComposer,
    $$TracksTableOrderingComposer,
    $$TracksTableAnnotationComposer,
    $$TracksTableCreateCompanionBuilder,
    $$TracksTableUpdateCompanionBuilder,
    (Track, $$TracksTableReferences),
    Track,
    PrefetchHooks Function({bool playlistTracksRefs})> {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> youtubeVideoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<String?> localFilePath = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> lyricsLrc = const Value.absent(),
            Value<DownloadStatus> downloadStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TracksCompanion(
            id: id,
            youtubeVideoId: youtubeVideoId,
            title: title,
            artist: artist,
            durationMs: durationMs,
            localFilePath: localFilePath,
            thumbnailPath: thumbnailPath,
            lyricsLrc: lyricsLrc,
            downloadStatus: downloadStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> youtubeVideoId = const Value.absent(),
            required String title,
            required String artist,
            Value<int> durationMs = const Value.absent(),
            Value<String?> localFilePath = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> lyricsLrc = const Value.absent(),
            Value<DownloadStatus> downloadStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TracksCompanion.insert(
            id: id,
            youtubeVideoId: youtubeVideoId,
            title: title,
            artist: artist,
            durationMs: durationMs,
            localFilePath: localFilePath,
            thumbnailPath: thumbnailPath,
            lyricsLrc: lyricsLrc,
            downloadStatus: downloadStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TracksTable, Track>(table),
                    $$TracksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedDataByColumns<Track, $TracksTable,
                            PlaylistTrack, $PlaylistTracksTable>(
                        currentTable: table,
                        referencedTable: $$TracksTableReferences
                            ._playlistTracksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .playlistTracksRefs,
                        currentColumn: 'id',
                        referencedColumn: 'track_id',
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TracksTable,
    Track,
    $$TracksTableFilterComposer,
    $$TracksTableOrderingComposer,
    $$TracksTableAnnotationComposer,
    $$TracksTableCreateCompanionBuilder,
    $$TracksTableUpdateCompanionBuilder,
    (Track, $$TracksTableReferences),
    Track,
    PrefetchHooks Function({bool playlistTracksRefs})>;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  required String id,
  required String name,
  Value<bool> isYoutubeSynced,
  Value<String?> youtubePlaylistId,
  Value<String?> youtubePlaylistUrl,
  Value<String?> thumbnailPath,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<bool> isYoutubeSynced,
  Value<String?> youtubePlaylistId,
  Value<String?> youtubePlaylistUrl,
  Value<String?> thumbnailPath,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
      _playlistTracksRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistTracks,
              aliasName: 'playlists__id__playlist_tracks__playlist_id');

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager($_db, $_db.playlistTracks)
        .filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isYoutubeSynced => $composableBuilder(
      column: $table.isYoutubeSynced,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get youtubePlaylistId => $composableBuilder(
      column: $table.youtubePlaylistId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get youtubePlaylistUrl => $composableBuilder(
      column: $table.youtubePlaylistUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> playlistTracksRefs(
      Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableFilterComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isYoutubeSynced => $composableBuilder(
      column: $table.isYoutubeSynced,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get youtubePlaylistId => $composableBuilder(
      column: $table.youtubePlaylistId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get youtubePlaylistUrl => $composableBuilder(
      column: $table.youtubePlaylistUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isYoutubeSynced => $composableBuilder(
      column: $table.isYoutubeSynced, builder: (column) => column);

  GeneratedColumn<String> get youtubePlaylistId => $composableBuilder(
      column: $table.youtubePlaylistId, builder: (column) => column);

  GeneratedColumn<String> get youtubePlaylistUrl => $composableBuilder(
      column: $table.youtubePlaylistUrl, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
      Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, $$PlaylistsTableReferences),
    Playlist,
    PrefetchHooks Function({bool playlistTracksRefs})> {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> isYoutubeSynced = const Value.absent(),
            Value<String?> youtubePlaylistId = const Value.absent(),
            Value<String?> youtubePlaylistUrl = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion(
            id: id,
            name: name,
            isYoutubeSynced: isYoutubeSynced,
            youtubePlaylistId: youtubePlaylistId,
            youtubePlaylistUrl: youtubePlaylistUrl,
            thumbnailPath: thumbnailPath,
            lastSyncedAt: lastSyncedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<bool> isYoutubeSynced = const Value.absent(),
            Value<String?> youtubePlaylistId = const Value.absent(),
            Value<String?> youtubePlaylistUrl = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion.insert(
            id: id,
            name: name,
            isYoutubeSynced: isYoutubeSynced,
            youtubePlaylistId: youtubePlaylistId,
            youtubePlaylistUrl: youtubePlaylistUrl,
            thumbnailPath: thumbnailPath,
            lastSyncedAt: lastSyncedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlaylistsTable, Playlist>(table),
                    $$PlaylistsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedDataByColumns<
                            Playlist,
                            $PlaylistsTable,
                            PlaylistTrack,
                            $PlaylistTracksTable>(
                        currentTable: table,
                        referencedTable: $$PlaylistsTableReferences
                            ._playlistTracksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlaylistsTableReferences(db, table, p0)
                                .playlistTracksRefs,
                        currentColumn: 'id',
                        referencedColumn: 'playlist_id',
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    Playlist,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (Playlist, $$PlaylistsTableReferences),
    Playlist,
    PrefetchHooks Function({bool playlistTracksRefs})>;
typedef $$PlaylistTracksTableCreateCompanionBuilder = PlaylistTracksCompanion
    Function({
  required String playlistId,
  required String trackId,
  required int position,
  Value<int> rowid,
});
typedef $$PlaylistTracksTableUpdateCompanionBuilder = PlaylistTracksCompanion
    Function({
  Value<String> playlistId,
  Value<String> trackId,
  Value<int> position,
  Value<int> rowid,
});

final class $$PlaylistTracksTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistTracksTable, PlaylistTrack> {
  $$PlaylistTracksTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager($_db, $_db.playlists)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_tracks__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableFilterComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableOrderingComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableAnnotationComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistTracksTable,
    PlaylistTrack,
    $$PlaylistTracksTableFilterComposer,
    $$PlaylistTracksTableOrderingComposer,
    $$PlaylistTracksTableAnnotationComposer,
    $$PlaylistTracksTableCreateCompanionBuilder,
    $$PlaylistTracksTableUpdateCompanionBuilder,
    (PlaylistTrack, $$PlaylistTracksTableReferences),
    PlaylistTrack,
    PrefetchHooks Function({bool playlistId, bool trackId})> {
  $$PlaylistTracksTableTableManager(
      _$AppDatabase db, $PlaylistTracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> playlistId = const Value.absent(),
            Value<String> trackId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistTracksCompanion(
            playlistId: playlistId,
            trackId: trackId,
            position: position,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String playlistId,
            required String trackId,
            required int position,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistTracksCompanion.insert(
            playlistId: playlistId,
            trackId: trackId,
            position: position,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlaylistTracksTable, PlaylistTrack>(table),
                    $$PlaylistTracksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (playlistId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.playlistId,
                    referencedTable:
                        $$PlaylistTracksTableReferences._playlistIdTable(db),
                    referencedColumn:
                        $$PlaylistTracksTableReferences._playlistIdTable(db).id,
                  ) as T;
                }
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$PlaylistTracksTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$PlaylistTracksTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlaylistTracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistTracksTable,
    PlaylistTrack,
    $$PlaylistTracksTableFilterComposer,
    $$PlaylistTracksTableOrderingComposer,
    $$PlaylistTracksTableAnnotationComposer,
    $$PlaylistTracksTableCreateCompanionBuilder,
    $$PlaylistTracksTableUpdateCompanionBuilder,
    (PlaylistTrack, $$PlaylistTracksTableReferences),
    PlaylistTrack,
    PrefetchHooks Function({bool playlistId, bool trackId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
}
