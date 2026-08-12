import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/home/constellation_page.dart';
import '../features/home/discover_tab.dart';
import '../features/home/home_shell.dart';
import '../features/home/library_tab.dart';
import '../features/home/profile_tab.dart';
import '../features/practice/practice_page.dart';
import '../features/profile/pitch_test_page.dart';
import '../features/profile/settings_page.dart';
import '../features/sandbox/sandbox_page.dart';
import '../features/workshop/workshop_note_editor_page.dart';
import '../features/workshop/workshop_page.dart';
import '../features/workshop/workshop_tools.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/discover',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (auth.isLoading) {
        if (!loggingIn) return '/login';
        return null;
      }
      if (!auth.isLoggedIn && !loggingIn) return '/login';
      if (auth.isLoggedIn && loggingIn) return '/discover';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(isRegister: false),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const LoginPage(isRegister: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workshop',
                builder: (context, state) {
                  final raw = state.uri.queryParameters['tool'];
                  WorkshopToolId? tool;
                  if (raw != null) {
                    for (final id in WorkshopToolId.values) {
                      if (id.name == raw) {
                        tool = id;
                        break;
                      }
                    }
                  }
                  return WorkshopPage(initialTool: tool);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileTab(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/practice/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PracticePage(songId: id);
        },
      ),
      GoRoute(
        path: '/workshop/edit-notes/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WorkshopNoteEditorPage(scoreId: id);
        },
      ),
      GoRoute(
        path: '/pitch-test',
        builder: (context, state) => const PitchTestPage(),
      ),
      GoRoute(
        path: '/sandbox',
        builder: (context, state) => const SandboxPage(),
      ),
      GoRoute(
        path: '/constellation',
        builder: (context, state) => const ConstellationPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}
