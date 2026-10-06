import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saidly/src/routing/app_route.dart';
import 'package:saidly/src/routing/not_found_screen.dart';

/// A throwaway router with the same wiring the real one will have: one home
/// route and NotFoundScreen as the errorBuilder.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home.name,
      builder: (_, _) => const Scaffold(body: Text('home screen')),
    ),
  ],
  errorBuilder: (_, _) => const NotFoundScreen(),
);

void main() {
  testWidgets('an unknown path lands on NotFoundScreen', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/no-such-page');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.text('home screen'), findsNothing);
  });

  testWidgets('the button goes home by name, not by path', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/no-such-page');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('home screen'), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  testWidgets('says something a person can read', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotFoundScreen()));

    // Not an assertion on exact wording — that moves to the .arb file. What
    // matters is that the screen is not blank and does not show a path.
    expect(find.byType(Text), findsWidgets);
    expect(find.textContaining('/'), findsNothing);
  });
}
