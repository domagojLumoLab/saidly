import '../localization/string_hardcoded.dart';

/// The sentence to put in front of a person for anything that was thrown.
///
/// One function rather than a ternary repeated at each call site, so the alert
/// dialog and AsyncValueWidget cannot drift into different wording for the
/// same failure.
///
/// Takes `Object` because that is what `AsyncValue.error` and a `catch` hand
/// you. An AppException already carries a sentence written for a reader;
/// anything else is one of our own bugs — a TypeError, a StateError, or a bare
/// `throw 'text'` from somebody's package — whose toString is a developer's
/// sentence. It stays in the logs; the screen gets this instead.
String messageForUser(Object error) => error is AppException
    ? error.message
    : 'Something went wrong. Please try again.'.hardcoded;

/// Every error this app is willing to show a person.
///
/// `sealed`, so the subclasses all live here and the analyzer can prove a
/// `switch` over them is exhaustive. The cost is that one file grows as
/// features arrive; the benefit is that the catalogue of what a user can be
/// told is a single thing you can read top to bottom.
///
/// Nothing in here imports Firebase, Dio or any other package. Translating a
/// `FirebaseAuthException` into one of these is the repository's job — that is
/// what keeps those packages inside `data/`.
sealed class AppException implements Exception {
  const AppException(this.code, this.message);

  /// Stable, machine-readable, snake_case — the same shape the API uses for
  /// its error codes. Tests and logs switch on this; users never see it.
  final String code;

  /// What the user reads. Written as a sentence, not as a status.
  ///
  /// English, held here rather than marked `.hardcoded`, because `.hardcoded`
  /// is a getter and a getter cannot run inside a `const` constructor. When
  /// the Croatian .arb lands these become a lookup on `code`, and this field
  /// goes away; until then this file is the one place to edit the wording.
  final String message;

  // Hand-written because Dart compares by identity by default.
  //
  // It is easy to think this is unnecessary: `const NetworkException()` is
  // canonicalised, so two such expressions are literally the same object and
  // identity already says they are equal. That holds only while BOTH sides are
  // const. The moment one is built at runtime — which is exactly what the
  // repository does, `UnknownAuthException(e.code)` with a code from Firebase
  // — identity fails and the assertion reports two values whose printed form
  // is character-for-character identical. Measured: deleting these two members
  // fails only the runtime-constructed case in app_exception_test.dart.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppException &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, code);

  /// For logs. The message is for screens, this is for whoever is debugging.
  @override
  String toString() => '$runtimeType($code)';
}

/// Wrong password, unknown account, or a malformed credential.
///
/// One exception for all three on purpose. Firebase projects created since
/// email-enumeration protection became the default answer every one of them
/// with `invalid-credential`, so the app cannot tell them apart — and should
/// not: "no account with that email" tells a stranger which emails are
/// registered.
final class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
    : super('invalid_credentials', 'Email or password is incorrect.');
}

/// The text in the email field is not an email address.
final class InvalidEmailException extends AppException {
  const InvalidEmailException()
    : super('invalid_email', 'That is not a valid email address.');
}

/// The account exists but has been switched off in the Firebase console.
final class UserDisabledException extends AppException {
  const UserDisabledException()
    : super('user_disabled', 'This account has been disabled.');
}

/// Firebase throttled this device after repeated failures.
final class TooManyRequestsException extends AppException {
  const TooManyRequestsException()
    : super(
        'too_many_requests',
        'Too many attempts. Try again in a few minutes.',
      );
}

/// The phone could not reach Firebase at all.
final class NetworkException extends AppException {
  const NetworkException()
    : super('network_unavailable', 'No connection. Check your network.');
}

/// The Saidly API refused the ID token.
///
/// Distinct from [InvalidCredentialsException], which is about typing the
/// wrong password. This one means a token that was valid has stopped being
/// accepted — and by the time it is thrown, the Dio interceptor has already
/// refreshed it once and been refused again.
final class SessionExpiredException extends AppException {
  const SessionExpiredException()
    : super('session_expired', 'Your session has ended. Please sign in again.');
}

/// The Saidly API answered, but not with success.
///
/// Carries the API's own `error.code` so a log says which route failed and
/// why, while the user gets a sentence. The API's `error.message` is
/// deliberately not shown: it is written for a developer reading a 500, and
/// some of them name tables and columns.
final class ApiException extends AppException {
  const ApiException(String apiCode)
    : super(apiCode, 'Saidly is having trouble. Please try again.');
}

/// Anything the repository did not recognise.
///
/// Carries the original code so a log says what actually happened, while the
/// user gets a sentence instead of `[firebase_auth/internal-error]`.
final class UnknownAuthException extends AppException {
  const UnknownAuthException(String originalCode)
    : super(originalCode, 'Something went wrong. Please try again.');
}
