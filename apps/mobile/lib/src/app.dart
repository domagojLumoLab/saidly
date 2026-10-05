import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';

/// The widget under `ProviderScope`, and nothing more.
///
/// It owns no state and makes no decisions: the router decides what is on
/// screen, `main.dart` decides what the app is wired to. Keeping it this thin
/// is what lets a test pump the whole app against a fake repository.
class App extends ConsumerWidget {
  const App({super.key});

  /// One seed, two schemes. Picking colours twice is how a dark mode drifts
  /// into looking like a different product.
  static const _seed = Color(0xFF3F6C51);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // Watched, not constructed here: the router is a provider so a test can
      // give it a fake AuthRepository and get a guard that behaves accordingly.
      routerConfig: ref.watch(goRouterProvider),
      title: 'Saidly',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      ),
      // The phone's setting, not ours. A planning app is used late in the
      // evening, which is exactly when a forced light theme is unpleasant.
      themeMode: ThemeMode.system,
    );
  }
}
