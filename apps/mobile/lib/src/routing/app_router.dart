import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/presentation/account_screen.dart';
import '../features/authentication/presentation/sign_in_screen.dart';
import 'app_route.dart';
import 'go_router_refresh_stream.dart';
import 'not_found_screen.dart';

/// The app's only GoRouter, consumed by `MaterialApp.router` in app.dart.
///
/// A `Provider` rather than a global, so a test can supply a fake
/// `AuthRepository` and get a router whose guard behaves accordingly.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  // Without this the guard would run once at startup and never again: signing
  // out would leave the user looking at a screen they are no longer allowed
  // to see until they happened to navigate.
  final refresh = GoRouterRefreshStream(authRepository.authStateChanges());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read synchronously rather than from the stream: redirect has to answer
      // now, and cannot await anything.
      final signedIn = authRepository.currentUser != null;
      final goingToSignIn = state.matchedLocation == '/signIn';

      if (!signedIn) {
        // Null when already heading there — returning '/signIn' from the
        // /signIn redirect is a loop go_router will refuse to run.
        return goingToSignIn ? null : '/signIn';
      }
      if (goingToSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.home.name,
        // Temporarily the account screen. In 008 today's tasks take this
        // route and the account moves to /settings.
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/signIn',
        name: AppRoute.signIn.name,
        builder: (context, state) => const SignInScreen(),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
  ref.onDispose(router.dispose);

  return router;
});
