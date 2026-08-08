import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/deep_link_provider.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'services/audio_player_handler.dart';
import 'ui/screens/about_screen.dart';
import 'ui/screens/album_detail_screen.dart';
import 'ui/screens/ai_scene_screen.dart';
import 'ui/screens/ai_compose_screen.dart';
import 'ui/screens/cache_management_screen.dart';
import 'ui/screens/exclusion_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/now_playing_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/online_screen.dart';
import 'ui/screens/playlist_import_export_screen.dart';
import 'ui/screens/playlist_screen.dart';
import 'ui/screens/radio_screen.dart';
import 'ui/screens/archive_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/stats_screen.dart';

/// App 根组件。
class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appThemeProvider);
    return MaterialApp.router(
      title: '袭明音乐',
      theme: AppTheme.light(settings.accent),
      darkTheme: AppTheme.dark(settings.accent),
      themeMode: settings.materialMode,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

final _rootNavKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final firstLaunchDone =
          prefs.getBool(AppConstants.prefFirstLaunch) ?? false;
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      if (!firstLaunchDone && !goingToOnboarding) return '/onboarding';
      if (firstLaunchDone && goingToOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/ai-scene',
        builder: (_, __) => const AiSceneScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/cache',
        builder: (_, __) => const CacheManagementScreen(),
      ),
      GoRoute(
        path: '/ai-compose',
        builder: (_, __) => const AiComposeScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (_, __) => const StatsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: '/exclusion',
        builder: (_, __) => const ExclusionScreen(),
      ),
      GoRoute(
        path: '/playlist-import-export',
        builder: (_, __) => const PlaylistImportExportScreen(),
      ),
      GoRoute(
        path: '/album/:album/:artist',
        builder: (_, state) => AlbumDetailScreen(
          album: Uri.decodeComponent(state.pathParameters['album']!),
          artist: Uri.decodeComponent(state.pathParameters['artist']!),
        ),
      ),
      GoRoute(
        path: '/artist/:artist',
        builder: (_, state) => ArtistDetailScreen(
          artist: Uri.decodeComponent(state.pathParameters['artist']!),
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (_, state) => PlaylistScreen(
          playlistId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/online/jamendo',
        builder: (_, __) => const JamendoScreen(),
      ),
      GoRoute(
        path: '/online/audius',
        builder: (_, __) => const AudiusScreen(),
      ),
    ],
  );

/// GoRouter Provider（让 deep link handler 能访问路由）
final goRouterProvider = Provider<GoRouter>((ref) => _router);