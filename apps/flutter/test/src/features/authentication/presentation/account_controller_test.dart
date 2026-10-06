import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/presentation/account_controller.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;
  late List<AsyncValue<void>> states;

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    states = [];
    container.listen<AsyncValue<void>>(
      accountControllerProvider,
      (_, state) => states.add(state),
      fireImmediately: true,
    );
  });

  AccountController controller() =>
      container.read(accountControllerProvider.notifier);

  test('starts idle', () {
    final state = container.read(accountControllerProvider);

    expect(state.isLoading, isFalse);
    expect(state.hasError, isFalse);
  });

  test('does not sign anybody out until asked', () {
    container.read(accountControllerProvider);

    verifyNever(repository.signOut);
  });

  test('loads, then settles, on success', () async {
    when(repository.signOut).thenAnswer((_) async {});

    await controller().signOut();

    expect(states.map((s) => '${s.isLoading}/${s.hasError}'), [
      'false/false',
      'true/false',
      'false/false',
    ]);
    verify(repository.signOut).called(1);
  });

  test('a failure lands in the state, not on the caller', () async {
    // Signing out revokes the session over the network, so it genuinely fails
    // offline. The button's onPressed must not need a try/catch.
    when(repository.signOut).thenThrow(const NetworkException());

    await expectLater(controller().signOut(), completes);

    final state = container.read(accountControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, const NetworkException());
  });

  test('the message survives for the dialog to show', () async {
    when(repository.signOut).thenThrow(const NetworkException());

    await controller().signOut();

    final error = container.read(accountControllerProvider).error;
    expect(
      (error! as AppException).message,
      'No connection. Check your network.',
    );
  });

  test('a retry after a failure can succeed', () async {
    when(repository.signOut).thenThrow(const NetworkException());
    await controller().signOut();
    expect(container.read(accountControllerProvider).hasError, isTrue);

    when(repository.signOut).thenAnswer((_) async {});
    await controller().signOut();

    expect(container.read(accountControllerProvider).hasError, isFalse);
  });
}
