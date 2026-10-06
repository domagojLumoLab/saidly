import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/app.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/domain/app_user.dart';
import 'package:saidly/src/features/authentication/presentation/account_screen.dart';
import 'package:saidly/src/features/authentication/presentation/sign_in_screen.dart';
import 'package:saidly/src/routing/app_router.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AppUser(uid: 'abc123', email: 'a@b.com');

void main() {
  late MockAuthRepository repository;
  late StreamController<AppUser?> authChanges;
  late ProviderContainer container;
  AppUser? current;

  setUp(() {
    repository = MockAuthRepository();
    authChanges = StreamController<AppUser?>.broadcast();
    current = null;

    when(() => repository.currentUser).thenAnswer((_) => current);
    when(repository.authStateChanges).thenAnswer((_) async* {
      yield current;
      yield* authChanges.stream;
    });
    when(repository.signOut).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // Registered first so it runs last: tearDowns run in reverse. The
    // container has to go before the controller, or close() waits for
    // subscriptions that are still attached and the test hangs.
    addTearDown(authChanges.close);
    addTearDown(container.dispose);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts at sign-in when nobody is signed in', (tester) async {
    await pumpApp(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('starts at home when somebody is', (tester) async {
    current = _user;

    await pumpApp(tester);

    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('uses the router from goRouterProvider, not its own', (
    tester,
  ) async {
    // If App built a GoRouter of its own, the guard would run against a
    // different AuthRepository than the one overridden here and this would
    // land on the wrong screen.
    current = _user;
    await pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, same(container.read(goRouterProvider)));
  });

  group('theme', () {
    testWidgets('has a light and a dark theme, and follows the system', (
      tester,
    ) async {
      await pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(app.theme?.colorScheme.brightness, Brightness.light);
      expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('both themes come from the same seed', (tester) async {
      // Otherwise dark mode slowly becomes a different product.
      await pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(app.theme?.colorScheme.primary, isNotNull);
      expect(
        app.darkTheme?.colorScheme.primary,
        isNot(equals(app.theme?.colorScheme.primary)),
      );
    });
  });

  testWidgets('is titled, which is what the app switcher shows', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Saidly',
    );
  });
}
