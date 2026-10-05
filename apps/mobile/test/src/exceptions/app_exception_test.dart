import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/exceptions/app_exception.dart';

void main() {
  group('equality', () {
    // Note what this does NOT prove: both sides are const, Dart canonicalises
    // const expressions, so this passes on identity alone even with == and
    // hashCode deleted. The test below it is the one that holds them in place.
    test('two instances of the same exception are equal', () {
      expect(
        const InvalidCredentialsException(),
        equals(const InvalidCredentialsException()),
      );
    });

    test('different exceptions are not equal', () {
      expect(
        const InvalidCredentialsException(),
        isNot(equals(const NetworkException())),
      );
    });

    // The test that earns the hand-written ==. `fromRuntime` builds the
    // exception from a value, the way the repository builds it from
    // FirebaseAuthException.code, so it is not canonicalised and identity
    // cannot save it. Delete == and only this test goes red.
    test('an exception built at runtime equals its const twin', () {
      AppException fromRuntime(String code) => UnknownAuthException(code);
      final code = ['quota', 'exceeded'].join('-');

      expect(identical(fromRuntime(code), fromRuntime(code)), isFalse);
      expect(
        fromRuntime(code),
        equals(const UnknownAuthException('quota-exceeded')),
      );
      expect(
        fromRuntime(code).hashCode,
        equals(const UnknownAuthException('quota-exceeded').hashCode),
      );
    });

    test('UnknownAuthException differs by the code it carries', () {
      expect(
        const UnknownAuthException('quota-exceeded'),
        isNot(equals(const UnknownAuthException('internal-error'))),
      );
    });

    test('equal exceptions share a hashCode', () {
      expect(
        const NetworkException().hashCode,
        equals(const NetworkException().hashCode),
      );
    });
  });

  group('contents', () {
    test('every exception carries a code and a message a user can read', () {
      const all = <AppException>[
        InvalidCredentialsException(),
        InvalidEmailException(),
        UserDisabledException(),
        TooManyRequestsException(),
        NetworkException(),
        UnknownAuthException('whatever'),
      ];

      for (final exception in all) {
        expect(exception.code, isNotEmpty, reason: '$exception has no code');
        expect(
          exception.message,
          isNotEmpty,
          reason: '$exception has no message',
        );
        // A message is shown to a person. If it reads like an identifier,
        // somebody put the code in the wrong field.
        expect(
          exception.message,
          isNot(equals(exception.code)),
          reason: '$exception shows its code as its message',
        );
      }
    });

    test('toString names the type and the code, for logs', () {
      expect(
        const NetworkException().toString(),
        equals('NetworkException(network_unavailable)'),
      );
    });
  });

  messageForUserTests();
}

// Appended: the shared helper both the dialog and AsyncValueWidget use, so
// the two cannot drift into showing different words for the same failure.
void messageForUserTests() {
  group('messageForUser', () {
    test('an AppException speaks for itself', () {
      expect(
        messageForUser(const NetworkException()),
        'No connection. Check your network.',
      );
    });

    test('anything else gets a sentence instead of its toString', () {
      final message = messageForUser(StateError('subscription cancelled'));

      expect(message, isNot(contains('subscription')));
      expect(message, isNot(contains('Instance of')));
      expect(message, isNotEmpty);
    });

    test('even a bare String is replaced', () {
      // `throw 'something'` is legal Dart and does happen in other people's
      // packages. It must not reach the screen verbatim.
      expect(messageForUser('raw internal detail'), isNot(contains('raw')));
    });
  });
}
