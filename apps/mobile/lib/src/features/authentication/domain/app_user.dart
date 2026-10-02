/// Who is signed in.
///
/// A domain model: no imports at all, not even firebase_auth. The repository
/// builds one of these from a `User` and nothing else in the app ever sees
/// Firebase's type. That is what makes it possible to test every screen and
/// controller without a Firebase instance.
class AppUser {
  const AppUser({required this.uid, required this.email});

  /// Firebase's `sub`. The same string the API reads out of the verified
  /// token and stores as `user_id` on every plan, task and ai_call row — so
  /// this value is the join between the phone and the database.
  final String uid;

  /// Non-nullable although `firebase_auth` types it as `String?`, because this
  /// app only ever signs people in with email and password. Reconciling the
  /// two is the repository's job, in one place, rather than a `?? ''` on every
  /// screen that wants to show it.
  final String email;

  // Hand-written rather than generated: two fields do not pay for Freezed and
  // a build step. The runtime-vs-const trap from AppException applies here
  // too, and app_user_test.dart covers it.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && uid == other.uid && email == other.email;

  @override
  int get hashCode => Object.hash(uid, email);

  /// Deliberately without the email. This string lands in logs, in Sentry
  /// breadcrumbs and in test failure output; a uid is opaque, an address is
  /// personal data. The API already refuses to log user text — same rule,
  /// other side of the wire.
  @override
  String toString() => 'AppUser($uid)';
}
