import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/features/authentication/domain/app_user.dart';

void main() {
  const user = AppUser(uid: 'abc123', email: 'domagoj@lumo-lab.com');

  group('equality', () {
    test('same uid and email are equal', () {
      expect(
        user,
        equals(const AppUser(uid: 'abc123', email: 'domagoj@lumo-lab.com')),
      );
    });

    test('a different uid is a different user', () {
      expect(
        user,
        isNot(
          equals(const AppUser(uid: 'xyz789', email: 'domagoj@lumo-lab.com')),
        ),
      );
    });

    test('the same person with a changed email is not the old value', () {
      expect(
        user,
        isNot(equals(const AppUser(uid: 'abc123', email: 'new@x.com'))),
      );
    });

    test('a user rebuilt at runtime equals its const twin', () {
      // Same trap as AppException: with both sides const, canonicalisation
      // makes identity enough and == is never exercised. The repository builds
      // this from a firebase_auth User, so the runtime case is the real one.
      final rebuilt = AppUser(uid: ['abc', '123'].join(), email: user.email);

      expect(identical(rebuilt, user), isFalse);
      expect(rebuilt, equals(user));
      expect(rebuilt.hashCode, equals(user.hashCode));
    });
  });

  group('toString', () {
    test('names the uid', () {
      expect(user.toString(), contains('abc123'));
    });

    test('never carries the email', () {
      // toString ends up in logs and crash reports. A uid is an opaque
      // identifier; an email address is personal data, and the API rules
      // already forbid logging user text. Same rule, other side of the wire.
      expect(user.toString(), isNot(contains('domagoj')));
      expect(user.toString(), isNot(contains('lumo-lab')));
    });
  });
}
