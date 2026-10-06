import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../exceptions/app_exception.dart';
import '../domain/app_user.dart';

/// The only file in the app that imports `firebase_auth`.
///
/// Everything above it speaks in `AppUser` and `AppException`, which is what
/// lets controllers, screens and the router be tested with a plain fake
/// instead of a Firebase instance. `FirebaseAuth` arrives as a constructor
/// argument for the same reason — the same injection the API does with `db`
/// and the LLM provider.
class AuthRepository {
  const AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Fires on every sign-in and sign-out. `GoRouterRefreshStream` listens to
  /// this so the redirect guard re-runs without anyone calling `go`.
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  /// Whoever is signed in at this instant. The router's `redirect` needs an
  /// answer synchronously; it cannot await a stream.
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _toAppException(e.code);
    }
  }

  /// Translated like `signInWithEmailAndPassword`, for the same reason:
  /// signing out revokes the session over the network, so it fails offline,
  /// and nothing outside this file knows what a FirebaseAuthException is.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _toAppException(e.code);
    }
  }

  /// The token the Dio interceptor puts in `Authorization`, and that the API
  /// verifies with `jose` against Google's JWKS.
  ///
  /// `forceRefresh` exists for exactly one caller: the interceptor, after a
  /// 401. Firebase caches the token for an hour, so a plain call would hand
  /// back the same expired string and the retry would fail identically.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Null means signed out.
  ///
  /// A user whose email is null counts as signed out too. This app only
  /// creates accounts with an email, so that state is an invariant we have no
  /// screen for; reporting signed-out sends the router to /signIn, which a
  /// person can recover from. Substituting an empty string would put a lie on
  /// screen and carry it into every API call.
  AppUser? _toAppUser(User? user) {
    final email = user?.email;
    if (user == null || email == null) return null;
    return AppUser(uid: user.uid, email: email);
  }

  /// Firebase's code, in Firebase's kebab-case, becomes one of ours.
  ///
  /// The first three collapse on purpose: projects with email enumeration
  /// protection — the default for anything created recently — answer
  /// `invalid-credential` for all of them, and telling a stranger "no account
  /// with that email" would confirm which addresses are registered.
  AppException _toAppException(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => const InvalidCredentialsException(),
    'invalid-email' => const InvalidEmailException(),
    'user-disabled' => const UserDisabledException(),
    'too-many-requests' => const TooManyRequestsException(),
    'network-request-failed' => const NetworkException(),
    _ => UnknownAuthException(code),
  };
}

/// Overridden in `main.dart` once Firebase is initialised, and in tests with a
/// fake. It throws rather than calling `FirebaseAuth.instance` here, so a test
/// that forgets the override fails loudly instead of reaching for a Firebase
/// that was never set up.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('authRepositoryProvider was not overridden'),
);

/// The stream the router and the account screen watch.
final authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
