import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/domain/app_user.dart';
import 'package:saidly/src/features/authentication/presentation/account_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AppUser(uid: 'abc123', email: 'domagoj@lumo-lab.com');

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(repository.authStateChanges).thenAnswer((_) => Stream.value(_user));
    when(repository.signOut).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSignOut(WidgetTester tester) async {
    await tester.tap(find.byKey(AccountScreen.signOutKey));
    await tester.pumpAndSettle();
  }

  /// The screen's button and the dialog's confirm action both say "Sign out",
  /// so a bare find.text matches two widgets and tap() refuses. Scoping to the
  /// dialog is the fix — renaming one of them to keep the test simple would be
  /// letting the test write the UI.
  Future<void> confirm(WidgetTester tester, String action) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(action),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('who is signed in', () {
    testWidgets('shows the email', (tester) async {
      await pumpScreen(tester);

      expect(find.text('domagoj@lumo-lab.com'), findsOneWidget);
    });

    testWidgets('shows the uid, which is what the API will answer with', (
      tester,
    ) async {
      // Spec 006's acceptance test compares this against the userId GET /me
      // returns. Until that call exists, having it on screen is what makes the
      // comparison possible at all.
      await pumpScreen(tester);

      expect(find.textContaining('abc123'), findsOneWidget);
    });

    testWidgets('spins while the stream has emitted nothing', (tester) async {
      when(repository.authStateChanges).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AccountScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('signing out', () {
    testWidgets('asks before doing it', (tester) async {
      await pumpScreen(tester);
      await tapSignOut(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(repository.signOut);
    });

    testWidgets('does nothing if the question is declined', (tester) async {
      await pumpScreen(tester);
      await tapSignOut(tester);

      await confirm(tester, 'Cancel');

      verifyNever(repository.signOut);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('signs out when confirmed', (tester) async {
      await pumpScreen(tester);
      await tapSignOut(tester);

      await confirm(tester, 'Sign out');

      verify(repository.signOut).called(1);
    });

    testWidgets('shows a spinner instead of the button while it runs', (
      tester,
    ) async {
      final pending = Completer<void>();
      when(repository.signOut).thenAnswer((_) => pending.future);

      await pumpScreen(tester);
      await tapSignOut(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(AccountScreen.signOutKey), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failure is shown as a sentence, not swallowed', (
      tester,
    ) async {
      when(repository.signOut).thenThrow(const NetworkException());

      await pumpScreen(tester);
      await tapSignOut(tester);
      await confirm(tester, 'Sign out');

      expect(find.text('No connection. Check your network.'), findsOneWidget);
    });
  });
}
