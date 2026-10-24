# DejaVu Playlist Sync — Technical Specification (SPEC.md)

## 1. Overview
DejaVu Playlist Sync (`dejavu_playlist_sync`) is an offline media archiver and playlist synchronizer built with Flutter. Its purpose is to link public and unlisted media playlists (such as Creative Commons tracks, podcasts, educational lectures, and personal media archives), perform background delta-syncs to download new tracks as pure losslessly-demuxed `.m4a` audio, prune removed tracks, maintain local audio storage without duplicates, and auto-export universal `.m3u8` playlist manifests for full compatibility with external Android and desktop players.

Remote YouTube playlists are the authoritative single source of truth: no manual playlist creation or manual track modification is required or exposed. All playlists are directly linked to YouTube playlists and kept synchronized via automated delta-syncs.

---

## 2. Tech Stack & Packages
- **Framework:** Flutter (Dart 3.x), targeting Android (API 26+) & iOS.
- **State Management:** `flutter_riverpod` (Riverpod 2.x with `StateNotifier` and selective rebuild tracking via `.select()`).
- **Local Relational Database:** `drift` + `sqlite3_flutter_libs` for embedded reactive SQLite queries, cascades, migrations, and aggregate count queries.
- **YouTube Extraction:** `youtube_explode_dart` for API-key-free playlist enumeration, lockup metadata scraping, and high-bitrate stream extraction.
- **Native Audio Interop:** Kotlin Android `MediaExtractor` and `MediaMuxer` integration via `MethodChannel` for 30ms lossless AAC stream demuxing (0 KB binary overhead vs 90MB FFmpegKit bloat, 0% CPU re-encoding penalty).
- **Universal Playlist Manifests:** RFC 8216 UTF-8 `.m3u8` exporter generating relative and portable playlist manifests.
- **Audio Playback:** `just_audio` + `just_audio_background` + `audio_session` for gapless playback, lock-screen notifications, headset buttons, and Android foreground audio service.
- **Storage & Networking:** `path_provider`, `dio` (for thumbnail caching & retry handling), `permission_handler`, `uuid`, `path`.

---

## 3. Architecture & Directory Structure
Inside `lib/`:
```
lib/
├── core/
│   ├── database/       # Drift schema, tables, reactive DAOs, SQLite count aggregations
│   ├── theme/          # DejaVu YouTube Dark Red & Carbon matte theme, Modern widgets
│   └── utils/          # FileUtils (.m3u8 generator, sanitizers), AudioNativeUtils, DurationFormatter
├── features/
│   ├── library/        # All Songs collection with live instant search & selective rebuilds
│   ├── player/         # AudioPlayerController, NowPlayingSheet, MiniPlayer, Queue modal
│   ├── playlists/      # PlaylistListScreen, PlaylistDetailScreen, NewPlaylistModal
│   └── sync_engine/    # YoutubeSyncService, Delta sync engine, lockup scraper, M3U8 export
└── main.dart           # App entrypoint, AudioSession configuration, background optimizer
```

---

## 4. Simplified Database Schema (Drift / SQLite)

### Table: `Playlists`
- `id`: TextColumn (UUID, Primary Key)
- `name`: TextColumn
- `isYoutubeSynced`: BoolColumn (Default: true)
- `youtubePlaylistId`: TextColumn (Unique, Non-null)
- `youtubePlaylistUrl`: TextColumn
- `thumbnailPath`: TextColumn (Nullable)
- `lastSyncedAt`: DateTimeColumn (Nullable)
- `createdAt`: DateTimeColumn

### Table: `Tracks`
- `id`: TextColumn (UUID, Primary Key)
- `youtubeVideoId`: TextColumn (Unique, Non-null)
- `title`: TextColumn
- `artist`: TextColumn
- `durationMs`: IntColumn (Default: 0)
- `localFilePath`: TextColumn (Nullable until download completes)
- `thumbnailPath`: TextColumn (Nullable)
- `lyricsLrc`: TextColumn (Nullable, synchronized LRC format)
- `downloadStatus`: IntColumn (Enum: `0 = pending`, `1 = downloading`, `2 = converting`, `3 = completed`, `4 = failed`)
- `createdAt`: DateTimeColumn

### Table: `PlaylistTracks` (Many-to-Many Join Table)
- `playlistId`: TextColumn (Foreign Key -> `Playlists.id` ON DELETE CASCADE)
- `trackId`: TextColumn (Foreign Key -> `Tracks.id` ON DELETE CASCADE)
- `position`: IntColumn
- Primary Key: `{playlistId, trackId}`

---

## 5. Delta-Sync Pipeline (`YoutubeSyncService`)
When `syncPlaylist(String playlistId)` is triggered:
1. **Remote Fetch:** Fetch remote metadata and videos via `YoutubeExplode().playlists.getVideos` with YouTube lockup HTML parsing fallback.
2. **Track Diffing & Auto-Healing:**
   - **New Tracks:** If `videoId` already exists in `Tracks` (`completed`), link in `PlaylistTracks` without re-downloading. Otherwise, insert into `Tracks` (`pending`), link in `PlaylistTracks`, and enqueue for download.
   - **Removed Tracks:** Unlink from `PlaylistTracks`. If `deleteOrphanedFiles == true` and the track is not referenced in any other playlist, delete local audio/thumbnail files and remove from `Tracks`.
   - **Self-Healing:** Automatically detect previously completed tracks with missing/corrupted cover art or missing lyrics and re-fetch them during sync without re-downloading audio bytes.
3. **Sequential Stream Downloading & Demuxing:**
   - Fetch audio stream manifest. Download raw stream via chunked pipe or Dio with automatic retries and connection reset recovery.
   - SponsorBlock Integration: Check `sponsor.ajay.app` for `music_offtopic` intro skits and calculate trim start offset.
   - Run lossless native demuxer (`AudioNativeUtils.stripVideoFromMp4`) with start offset trimming to produce pure AAC `.m4a` files.
   - Multi-Resolution 1:1 Thumbnail Crop: Download best available thumbnail (`maxresdefault` down to `default`) and center-crop natively to 1:1 square without black letterboxing.
   - Synchronized Lyrics: Fetch YouTube closed captions or query LRCLIB fallback to store millisecond-synchronized `.lrc` lyrics.
   - Android Media Scanner: Notify Android's `MediaScannerConnection` so external music players index newly downloaded tracks immediately.
4. **Metadata & Artwork Update:** Update playlist name and cover thumbnail path based on the first track with valid artwork.
5. **M3U8 Manifest Generation:** Automatically generate or update `<playlist_name>.m3u8` in the audio directory containing ordered local file paths and notify media scanner.

---

## 6. Universal M3U8 Playlist Manifest Pipeline
To ensure synced playlists are instantly recognized by external Android media players (VLC, Poweramp, Musicolet, BlackPlayer, Symfonium, USB car audio systems), `FileUtils.writeM3U8File` produces standard RFC 8216 UTF-8 `.m3u8` playlist files alongside downloaded audio:
- **Format:**
  ```text
  #EXTM3U
  #PLAYLIST:<Playlist Name>
  #EXTINF:<DurationSeconds>,<Artist> - <Title>
  <relative_filename>.m4a
  ```
- **File System Sanitization:** Names are sanitized via `FileUtils.sanitizeFilename` to remove illegal characters (`\ / : * ? " < > |`) ensuring compatibility across Android FAT32, SD Cards, ext4, and Windows USB file transfers.
- **Auto-Sync Trigger:** Manifests are refreshed automatically whenever delta-sync finishes, tracks are reordered, or orphan tracks are pruned.

---

## 7. UI/UX Design System (YouTube Music Matte-Dark & Crimson Aesthetic)
- **Aesthetic:** Clean, borderless, matte-dark consumer music streaming UI inspired by YouTube Music dark mode. Layered surfaces, capsule filter pills, ambient header gradients, and micro-badges replace harsh neon borders and monospace fonts. No references to external services.
- **Colors:**
  - **Scaffold Background:** `#0F0F0F` (YouTube Music's deep matte carbon base, easy on the eyes).
  - **Surface / Cards / Modals:** `#1E1E1E` (Zero borders, 12px radius).
  - **Floating Mini-Player Surface:** `#282828` (Floats 8px above bottom nav with 10px rounded corners).
  - **Primary Brand Accent:** `#C0151B` (Deep YouTube Crimson Red for oversized Play FAB, active track highlights, progress bars, and badges).
  - **Text Primary / Secondary:** `#FFFFFF` crisp white for song titles and FAB icons; `#B3B3B3` warm muted gray for artist names and durations.
- **Key Modern UI Patterns:**
  1. **Clean Track Row & Micro-Badges:** Displays artist and duration cleanly, with a 12px circular spinner while downloading.
  2. **Ambient Header Gradient:** Playlist detail screen blends a soft top-to-bottom linear gradient (from dark crimson ambient cover tones `#421014` down into `#0F0F0F`), with a centered 200×200 shadow-cast album cover.
  3. **Action Row with Oversized Play FAB:** Directly under playlist info, secondary circular icon buttons on the left (`Sync ↻`, `Shuffle 🔀`) and an oversized 56px solid circular crimson Play button on the right with a crisp white play icon.
  4. **Floating Rounded Mini-Player:** Sits 8px above bottom nav with 10px corners, album art thumbnail, title, artist, play/pause toggle, skip next, and a 2px crimson progress bar along the bottom edge.

---

## 8. Phone Optimization, CPU & Memory Leak Hardening
1. **Native GPU Texture Downscaling (`cacheWidth`):**
   - List thumbnails (48x48) are decoded with `cacheWidth: 120`.
   - Playlist cards (60x60) use `cacheWidth: 150`.
   - Full cover art uses `cacheWidth: 500` - `600`.
   - **Impact:** Prevents decoding full 480x360 uncompressed RGBA bitmaps into GPU RAM, achieving over **90% reduction in image memory footprint** and preventing Android Out-Of-Memory (OOM) errors during fast scrolling.
2. **Zero-Blocking UI Thread (Elimination of Synchronous File I/O):**
   - Removed blocking `File.existsSync()` filesystem syscalls from all widget `build()` methods.
   - Replaced with Flutter's native asynchronous `Image.file(..., errorBuilder: ...)` fallback rendering, ensuring 60/120 FPS frame rates without disk I/O stalls on the main isolate.
3. **Selective Riverpod Subscriptions & Component Isolation:**
   - `NowPlayingSheet` isolates high-frequency slider updates into `_NowPlayingProgressSection`, leaving cover art, title, and blur shadows un-rebuilt during playback.
   - `MiniPlayer` isolates the 2px progress bar into `_MiniPlayerProgressBar`, preventing entire player container and image rebuilds.
   - `LibraryScreen` and `PlaylistDetailScreen` subscribe selectively via `ref.watch(audioPlayerControllerProvider.select((s) => s.currentTrack?.id))`.
   - **Impact:** Completely eliminates 5 to 10 full-screen widget rebuilds per second during audio playback (over **600 layout passes eliminated per minute**), keeping the phone cool and saving battery.
4. **Cached Reactive StreamProviders & SQLite WAL Mode:**
   - Screen widgets consume memoized `StreamProvider`s (`playlistsWithCountsStreamProvider`, `allTracksStreamProvider`, `playlistTracksStreamProvider`) avoiding stream re-creation and query thrashing during sync progress ticks and text searches.
   - Drift database runs with `PRAGMA journal_mode = WAL`, `PRAGMA synchronous = NORMAL`, and `PRAGMA temp_store = MEMORY`, enabling concurrent non-blocking reads and minimal flash wear.
5. **Continuous Background Playback & Android Doze Hardening:**
   - Foreground notification service persistence (`androidStopForegroundOnPause: false`, `androidNotificationIcon: 'mipmap/ic_launcher'`) prevents Android 12+ Doze mode and task killer policies from tearing down playback after 2 minutes when app is backgrounded or screen locked.
   - Non-lazy audio source queueing (`useLazyPreparation: false`) ensures the next track's local file buffer is loaded before the active track concludes, avoiding gap starvation.
6. **Elimination of Startup Demux Loops:**
   - Removed startup full-library demux loops in `MainScaffold.initState`, keeping app launches instant and eliminating disk I/O contention and thermal throttling.
7. **StreamSubscription Lifecycle Management:**
   - `AudioPlayerController` retains all player stream subscriptions in an internal registry and cancels every subscription cleanly upon `dispose()`, preventing memory leaks across state reloads.
8. **Native Lossless Audio Demuxer vs FFmpegKit:**
   - Lightweight, zero-dependency Android MediaExtractor/MediaMuxer implementation (`AudioNativeUtils.stripVideoFromMp4`) that demuxes pure AAC streams losslessly at ~50MB/s without bundling large 80MB FFmpeg native `.so` shared libraries.
9. **Interactive Synchronized Lyrics (LRC Engine):**
   - High-precision timestamp parser (`LrcParser`) converts standard LRC formats into millisecond-accurate streams.
   - Integrated into `NowPlayingSheet` with an interactive pill toggle (replacing format technical labels), smooth cubic auto-scrolling centering the active lyric line, and tap-to-seek functionality.
   - Eliminates the 65MB - 90MB binary bloat of FFmpegKit.
   - Uses Android native `MediaExtractor` / `MediaMuxer` to strip multiplexed 360p H.264 video streams losslessly in under 30ms per track, preventing ExoPlayer video decoder buffer allocation and audio buffer underruns.
9. **Seek Throttling & Decoupled Scrubbing (`_AudioSeekSlider`):**
   - Local 60 FPS slider thumb updates during user touch drag (`onChanged`) without sending seek requests to ExoPlayer.
   - Single clean seek dispatched only upon user release (`onChangeEnd`), avoiding `AudioTrack.flush()` popping artifacts.
