import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/dejavu_theme.dart';
import 'features/library/library_screen.dart';
import 'features/player/audio_player_controller.dart';
import 'features/player/mini_player.dart';
import 'features/playlists/playlist_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.dejavu.player.channel.audio',
        androidNotificationChannelName: 'DejaVu Music Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_music_notification',
      );
    } catch (e) {
      debugPrint('Audio service init error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: DejaVuApp(),
    ),
  );
}

class DejaVuApp extends StatelessWidget {
  const DejaVuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DejaVu Playlist Sync',
      debugShowCheckedModeBanner: false,
      theme: DejaVuTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  AppLifecycleListener? _lifecycleListener;

  final _screens = const [
    PlaylistListScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () {
        ref.read(audioPlayerControllerProvider.notifier).stopAndClear();
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (e) {
        debugPrint('Notification permission error: $e');
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DejaVuColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: DejaVuColors.background,
              selectedItemColor: DejaVuColors.textPrimary,
              unselectedItemColor: DejaVuColors.textSecondary,
              selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 11),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.queue_music_rounded),
                  label: 'Playlists',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.music_note_rounded),
                  label: 'All Songs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
