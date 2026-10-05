import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';

part 'account_controller.g.dart';

/// Signing out.
///
/// Separate from [SignInController] because the two never coexist: one runs
/// on the sign-in screen, the other behind the guard. Sharing a controller
/// would mean a failed sign-in and a failed sign-out competing for the same
/// `AsyncValue`.
///
/// Who is signed in is not here. That is `authStateChangesProvider`, which the
/// router already watches — so sign-out needs no navigation code at all: the
/// stream fires, the guard re-runs, and the redirect does the moving.
@riverpod
class AccountController extends _$AccountController {
  @override
  FutureOr<void> build() {
    // Nothing to load.
  }

  /// Never throws; the failure goes into `state`.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}
