import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/features/authentication/data/auth_repository.dart';
import 'package:saidly/src/features/authentication/presentation/sign_in_controller.dart';

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
      signInControllerProvider,
      (_, state) => states.add(state),
      fireImmediately: true,
    );
  });

  SignInController controller() =>
      container.read(signInControllerProvider.notifier);

  void givenSignInSucceeds() {
    when(
      () => repository.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  }

  void givenSignInFails(AppException exception) {
    when(
      () => repository.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(exception);
  }

  test('starts idle, with nothing loading and nothing wrong', () {
    final state = container.read(signInControllerProvider);

    expect(state.isLoading, isFalse);
    expect(state.hasError, isFalse);
  });

  test('does not touch the repository until asked', () {
    container.read(signInControllerProvider);

    verifyNever(
      () => repository.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('loads, then settles, on success', () async {
    givenSignInSucceeds();

    await controller().signIn(email: 'a@b.com', password: 'secret');

    expect(states.map((s) => '${s.isLoading}/${s.hasError}'), [
      'false/false',
      'true/false',
      'false/false',
    ]);
  });

  test('passes the credentials through unchanged', () async {
    givenSignInSucceeds();

    await controller().signIn(email: 'a@b.com', password: 'secret');

    verify(
      () => repository.signInWithEmailAndPassword(
        email: 'a@b.com',
        password: 'secret',
      ),
    ).called(1);
  });

  test('a failure lands in the state, not on the caller', () async {
    givenSignInFails(const InvalidCredentialsException());

    // The widget calls this without a try/catch. If signIn rethrew, every
    // onPressed in the app would need one, and an unhandled error in a button
    // callback crashes the zone rather than showing a dialog.
    await expectLater(
      controller().signIn(email: 'a@b.com', password: 'wrong'),
      completes,
    );

    final state = container.read(signInControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, const InvalidCredentialsException());
  });

  test('the exception arrives intact, not wrapped', () async {
    givenSignInFails(const NetworkException());

    await controller().signIn(email: 'a@b.com', password: 'x');

    final error = container.read(signInControllerProvider).error;
    expect(error, isA<NetworkException>());
    expect(
      (error! as AppException).message,
      'No connection. Check your network.',
    );
  });

  test('a retry after a failure can succeed', () async {
    givenSignInFails(const InvalidCredentialsException());
    await controller().signIn(email: 'a@b.com', password: 'wrong');
    expect(container.read(signInControllerProvider).hasError, isTrue);

    givenSignInSucceeds();
    await controller().signIn(email: 'a@b.com', password: 'right');

    expect(container.read(signInControllerProvider).hasError, isFalse);
  });
}
