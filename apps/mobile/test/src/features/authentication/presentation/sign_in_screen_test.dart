import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/presentation/sign_in_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SignInScreen()),
      ),
    );
  }

  Future<void> fillIn(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(find.byKey(SignInScreen.emailKey), email);
    await tester.enterText(find.byKey(SignInScreen.passwordKey), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();
  }

  void givenSignInSucceeds() {
    when(
      () => repository.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  }

  void verifyNoAttempt() {
    verifyNever(
      () => repository.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  }

  group('the form', () {
    testWidgets('shows an email field, a password field and a button', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(SignInScreen.emailKey), findsOneWidget);
      expect(find.byKey(SignInScreen.passwordKey), findsOneWidget);
      expect(find.byKey(SignInScreen.submitKey), findsOneWidget);
    });

    testWidgets('hides the password as it is typed', (tester) async {
      await pumpScreen(tester);

      // TextFormField does not expose obscureText; it forwards it to the
      // EditableText that actually paints the characters, so that is what the
      // assertion has to reach.
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(SignInScreen.passwordKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });
  });

  group('refuses to call the server with input that cannot work', () {
    testWidgets('an empty email', (tester) async {
      await pumpScreen(tester);
      await fillIn(tester, email: '', password: 'secret123');
      await submit(tester);

      verifyNoAttempt();
    });

    testWidgets('an email with no @', (tester) async {
      await pumpScreen(tester);
      await fillIn(tester, email: 'domagoj', password: 'secret123');
      await submit(tester);

      verifyNoAttempt();
    });

    testWidgets('a password shorter than Firebase accepts', (tester) async {
      // Firebase refuses anything under six characters. Checking here saves a
      // round trip and gives the message next to the field instead of in a
      // dialog.
      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: 'abc');
      await submit(tester);

      verifyNoAttempt();
    });

    testWidgets('and says so next to the field, not in a dialog', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillIn(tester, email: 'nonsense', password: 'secret123');
      await submit(tester);

      expect(find.byType(AlertDialog), findsNothing);
      // Some message is on screen; the exact words move to the .arb file.
      expect(
        find.descendant(
          of: find.byKey(SignInScreen.emailKey),
          matching: find.byType(Text),
        ),
        findsWidgets,
      );
    });
  });

  group('with input that could work', () {
    testWidgets('signs in with exactly what was typed', (tester) async {
      givenSignInSucceeds();
      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: 'secret123');
      await submit(tester);

      verify(
        () => repository.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'secret123',
        ),
      ).called(1);
    });

    testWidgets('trims the email, because keyboards add spaces', (
      tester,
    ) async {
      givenSignInSucceeds();
      await pumpScreen(tester);
      await fillIn(tester, email: '  a@b.com ', password: 'secret123');
      await submit(tester);

      verify(
        () => repository.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'secret123',
        ),
      ).called(1);
    });

    testWidgets('never trims the password', (tester) async {
      // A space is a legitimate character in a password. Trimming it would
      // lock somebody out of their own account with no way to find out why.
      givenSignInSucceeds();
      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: ' secret ');
      await submit(tester);

      verify(
        () => repository.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: ' secret ',
        ),
      ).called(1);
    });
  });

  group('while the request is in flight', () {
    testWidgets('shows a spinner instead of the button', (tester) async {
      final pending = Completer<void>();
      when(
        () => repository.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => pending.future);

      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: 'secret123');
      await tester.tap(find.byKey(SignInScreen.submitKey));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(SignInScreen.submitKey), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();
    });
  });

  group('when sign-in fails', () {
    testWidgets('shows the exception message in a dialog', (tester) async {
      when(
        () => repository.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const InvalidCredentialsException());

      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: 'wrong123');
      await submit(tester);

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('leaves what was typed alone, so it can be corrected', (
      tester,
    ) async {
      when(
        () => repository.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const InvalidCredentialsException());

      await pumpScreen(tester);
      await fillIn(tester, email: 'a@b.com', password: 'wrong123');
      await submit(tester);

      expect(find.text('a@b.com'), findsOneWidget);
    });
  });
}
