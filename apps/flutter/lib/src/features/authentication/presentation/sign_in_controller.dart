import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';

part 'sign_in_controller.g.dart';

/// Drives the sign-in screen.
///
/// Its state is `AsyncValue<void>` — void because signing in produces no value
/// the screen needs. What the screen needs is the three phases: idle, in
/// flight, failed. Who is signed in afterwards comes from
/// `authStateChangesProvider`, not from here, so the two never disagree.
@riverpod
class SignInController extends _$SignInController {
  @override
  FutureOr<void> build() {
    // Nothing to load. The screen opens idle.
  }

  /// Never throws.
  ///
  /// The failure goes into `state` instead, which is what lets the button's
  /// onPressed stay a one-liner. An exception thrown out of a callback like
  /// that is not caught by any widget — it reaches the zone's error handler
  /// and the user sees nothing at all.
  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email: email, password: password),
    );
  }
}
