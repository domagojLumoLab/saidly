// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(AccountController)
final accountControllerProvider = AccountControllerProvider._();

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
final class AccountControllerProvider
    extends $AsyncNotifierProvider<AccountController, void> {
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
  AccountControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountControllerHash();

  @$internal
  @override
  AccountController create() => AccountController();
}

String _$accountControllerHash() => r'0890f7bbd05539573e046d58f7125f3bd53e5bfb';

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

abstract class _$AccountController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
