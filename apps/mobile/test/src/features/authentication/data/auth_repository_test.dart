import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/domain/app_user.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

/// A firebase_auth User with the fields we read already stubbed.
MockUser firebaseUser({String uid = 'abc123', String? email = 'a@b.com'}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn(email);
  return user;
}

void main() {
  late MockFirebaseAuth auth;
  late AuthRepository repository;

  setUp(() {
    auth = MockFirebaseAuth();
    repository = AuthRepository(auth);
  });

  group('signInWithEmailAndPassword', () {
    void givenFirebaseThrows(String code) {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: code));
    }

    test('passes the credentials through on success', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => MockUserCredential());

      await repository.signInWithEmailAndPassword(
        email: 'a@b.com',
        password: 'secret',
      );

      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'secret',
        ),
      ).called(1);
    });

    test('the three codes for a bad login collapse into one exception', () async {
      // Firebase answers invalid-credential on projects with email enumeration
      // protection, and the older two codes on projects without it. The user is
      // told the same thing either way.
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
      ]) {
        givenFirebaseThrows(code);
        await expectLater(
          repository.signInWithEmailAndPassword(
            email: 'a@b.com',
            password: 'x',
          ),
          throwsA(const InvalidCredentialsException()),
          reason: '$code should be an InvalidCredentialsException',
        );
      }
    });

    test('maps the codes that deserve their own message', () async {
      final expected = {
        'invalid-email': const InvalidEmailException(),
        'user-disabled': const UserDisabledException(),
        'too-many-requests': const TooManyRequestsException(),
        'network-request-failed': const NetworkException(),
      };

      for (final entry in expected.entries) {
        givenFirebaseThrows(entry.key);
        await expectLater(
          repository.signInWithEmailAndPassword(
            email: 'a@b.com',
            password: 'x',
          ),
          throwsA(entry.value),
          reason: '${entry.key} should be ${entry.value}',
        );
      }
    });

    test('an unrecognised code keeps itself but not for the user', () async {
      givenFirebaseThrows('quota-exceeded');

      await expectLater(
        repository.signInWithEmailAndPassword(email: 'a@b.com', password: 'x'),
        throwsA(
          isA<UnknownAuthException>()
              .having((e) => e.code, 'code', 'quota-exceeded')
              .having((e) => e.message, 'message', isNot(contains('quota'))),
        ),
      );
    });

    test('a FirebaseAuthException never escapes the repository', () async {
      givenFirebaseThrows('whatever-comes-next');

      await expectLater(
        repository.signInWithEmailAndPassword(email: 'a@b.com', password: 'x'),
        throwsA(isNot(isA<FirebaseAuthException>())),
      );
    });
  });

  group('authStateChanges', () {
    test('turns a firebase User into an AppUser', () {
      when(auth.authStateChanges).thenAnswer(
        (_) => Stream.value(firebaseUser(uid: 'u1', email: 'a@b.com')),
      );

      expect(
        repository.authStateChanges(),
        emits(const AppUser(uid: 'u1', email: 'a@b.com')),
      );
    });

    test('signed out is null, not an empty user', () {
      when(auth.authStateChanges).thenAnswer((_) => Stream.value(null));

      expect(repository.authStateChanges(), emits(isNull));
    });

    test('a user without an email counts as signed out', () {
      // This app only creates accounts with an email, so a null email is an
      // invariant we do not have a screen for. Reporting signed-out sends the
      // router to /signIn, which is recoverable; inventing an empty address
      // would put a lie on screen and into every API call.
      when(auth.authStateChanges)
          .thenAnswer((_) => Stream.value(firebaseUser(email: null)));

      expect(repository.authStateChanges(), emits(isNull));
    });
  });

  group('currentUser', () {
    test('reads whoever firebase_auth is holding right now', () {
      // Built before the when(), not inside thenReturn: firebaseUser() calls
      // when() itself, and mocktail refuses a when() nested in a when().
      final user = firebaseUser(uid: 'u2');
      when(() => auth.currentUser).thenReturn(user);

      expect(
        repository.currentUser,
        const AppUser(uid: 'u2', email: 'a@b.com'),
      );
    });

    test('is null when nobody is signed in', () {
      when(() => auth.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });
  });

  group('signOut', () {
    test('forwards to firebase_auth', () async {
      when(auth.signOut).thenAnswer((_) async {});

      await repository.signOut();

      verify(auth.signOut).called(1);
    });

    test('translates a failure like signIn does', () async {
      // Signing out hits the network to revoke the session, so it can fail
      // offline. Without this the raw FirebaseAuthException would reach the
      // dialog, which shows AppException.message for ours and a generic
      // sentence for everything else — so the user would learn nothing.
      when(auth.signOut)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      await expectLater(
        repository.signOut(),
        throwsA(const NetworkException()),
      );
    });

    test('an unrecognised failure keeps its code for the log', () async {
      when(auth.signOut)
          .thenThrow(FirebaseAuthException(code: 'internal-error'));

      await expectLater(
        repository.signOut(),
        throwsA(
          isA<UnknownAuthException>().having(
            (e) => e.code,
            'code',
            'internal-error',
          ),
        ),
      );
    });
  });

  group('idToken', () {
    test('returns null when nobody is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(await repository.idToken(), isNull);
    });

    test('asks for a cached token by default', () async {
      final user = firebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdToken(any())).thenAnswer((_) async => 'jwt');

      expect(await repository.idToken(), 'jwt');
      verify(() => user.getIdToken(false)).called(1);
    });

    test('forces a refresh when asked — the 401 retry path', () async {
      final user = firebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.getIdToken(any())).thenAnswer((_) async => 'fresh');

      expect(await repository.idToken(forceRefresh: true), 'fresh');
      verify(() => user.getIdToken(true)).called(1);
    });
  });
}
