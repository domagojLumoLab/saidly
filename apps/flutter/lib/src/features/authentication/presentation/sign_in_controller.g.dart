// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_in_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the sign-in screen.
///
/// Its state is `AsyncValue<void>` — void because signing in produces no value
/// the screen needs. What the screen needs is the three phases: idle, in
/// flight, failed. Who is signed in afterwards comes from
/// `authStateChangesProvider`, not from here, so the two never disagree.

@ProviderFor(SignInController)
final signInControllerProvider = SignInControllerProvider._();

/// Drives the sign-in screen.
///
/// Its state is `AsyncValue<void>` — void because signing in produces no value
/// the screen needs. What the screen needs is the three phases: idle, in
/// flight, failed. Who is signed in afterwards comes from
/// `authStateChangesProvider`, not from here, so the two never disagree.
final class SignInControllerProvider
    extends $AsyncNotifierProvider<SignInController, void> {
  /// Drives the sign-in screen.
  ///
  /// Its state is `AsyncValue<void>` — void because signing in produces no value
  /// the screen needs. What the screen needs is the three phases: idle, in
  /// flight, failed. Who is signed in afterwards comes from
  /// `authStateChangesProvider`, not from here, so the two never disagree.
  SignInControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signInControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signInControllerHash();

  @$internal
  @override
  SignInController create() => SignInController();
}

String _$signInControllerHash() => r'bfade76d91377a971e0ec0d3f5cef65772b231ee';

/// Drives the sign-in screen.
///
/// Its state is `AsyncValue<void>` — void because signing in produces no value
/// the screen needs. What the screen needs is the three phases: idle, in
/// flight, failed. Who is signed in afterwards comes from
/// `authStateChangesProvider`, not from here, so the two never disagree.

abstract class _$SignInController extends $AsyncNotifier<void> {
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
