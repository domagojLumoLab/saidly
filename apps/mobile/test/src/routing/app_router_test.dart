import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/domain/app_user.dart';
import 'package:saidly/src/features/authentication/presentation/account_screen.dart';
import 'package:saidly/src/features/authentication/presentation/sign_in_screen.dart';
import 'package:saidly/src/routing/app_router.dart';
import 'package:saidly/src/routing/not_found_screen.dart';

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

    when(() => repository.currentUser).thenReturn(null);

    // Emits the current user on subscribe, then whatever the test pushes.
    //
    // The leading `yield` is not test scaffolding: firebase_auth's real
    // authStateChanges() also fires immediately with whoever is signed in. A
    // fake that only emits on change leaves every screen watching it stuck on
    // a spinner — and a spinner never settles, so the test hangs rather than
    // failing.
    //
    // async* also gives each subscriber its own stream, which matters because
    // Riverpod subscribes more than once and a single-subscription stream
    // throws on the second listener.
    when(repository.authStateChanges).thenAnswer((_) async* {
      yield current;
      yield* authChanges.stream;
    });
    when(repository.signOut).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // Order matters, and it is the reverse of how it reads: tearDowns run
    // last-registered-first. The container must go first so every subscription
    // is cancelled, and only then the controller. Closed the other way round,
    // close() waits for consumers that are still attached and the test hangs
    // instead of failing.
    addTearDown(authChanges.close);
    addTearDown(container.dispose);
  });

  void givenSignedIn() {
    current = _user;
    when(() => repository.currentUser).thenReturn(_user);
  }

  void givenSignedOut() {
    current = null;
    when(() => repository.currentUser).thenReturn(null);
  }

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = container.read(goRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('where you land', () {
    testWidgets('signed out, you start at sign-in', (tester) async {
      givenSignedOut();

      await pumpApp(tester);

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(AccountScreen), findsNothing);
    });

    testWidgets('signed in, you start at home', (tester) async {
      givenSignedIn();

      await pumpApp(tester);

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });
  });

  group('the guard', () {
    testWidgets('signed out, every route becomes sign-in', (tester) async {
      givenSignedOut();
      final router = await pumpApp(tester);

      router.go('/');
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('signed in, sign-in sends you home', (tester) async {
      givenSignedIn();
      final router = await pumpApp(tester);

      router.goNamed('signIn');
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });
  });

  group('the guard re-runs on its own', () {
    testWidgets('signing in moves you off the sign-in screen', (tester) async {
      // Nobody calls context.go here. The stream fires, GoRouterRefreshStream
      // notifies, redirect runs again. This is the whole reason that class
      // exists.
      givenSignedOut();
      await pumpApp(tester);
      expect(find.byType(SignInScreen), findsOneWidget);

      givenSignedIn();
      authChanges.add(_user);
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('signing out moves you off a screen you may not see', (
      tester,
    ) async {
      givenSignedIn();
      await pumpApp(tester);
      expect(find.byType(AccountScreen), findsOneWidget);

      givenSignedOut();
      authChanges.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('an unknown location', () {
    testWidgets('signed in, shows NotFoundScreen', (tester) async {
      givenSignedIn();
      final router = await pumpApp(tester);

      router.go('/no-such-page');
      await tester.pumpAndSettle();

      expect(find.byType(NotFoundScreen), findsOneWidget);
    });

    testWidgets('signed out, the guard wins over the 404', (tester) async {
      // Being asked to sign in is more useful than being told a page you were
      // never allowed to see does not exist.
      givenSignedOut();
      final router = await pumpApp(tester);

      router.go('/no-such-page');
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(NotFoundScreen), findsNothing);
    });
  });
}
