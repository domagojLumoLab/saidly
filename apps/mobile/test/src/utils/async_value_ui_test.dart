import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/exceptions/app_exception.dart';
import 'package:saidly/src/utils/async_value_ui.dart';

/// A controller written exactly as CLAUDE.md prescribes, used to produce a
/// real retry state instead of reaching for Riverpod's @internal
/// copyWithPrevious.
class _Controller extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> attempt({required bool fail}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (fail) throw const NetworkException();
    });
  }
}

final _controllerProvider = AsyncNotifierProvider<_Controller, void>(
  _Controller.new,
);

/// The state a screen is shown while a retry is in flight after a failure.
///
/// Measured, not assumed: assigning `const AsyncLoading()` to an AsyncNotifier
/// does not discard what came before — Riverpod keeps the previous AsyncError
/// attached, so this value has isLoading and hasError both true.
Future<AsyncValue<void>> whileRetryingAfterAFailure() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  final seen = <AsyncValue<void>>[];
  container.listen<AsyncValue<void>>(
    _controllerProvider,
    (_, state) => seen.add(state),
  );

  await container.read(_controllerProvider.notifier).attempt(fail: true);
  await container.read(_controllerProvider.notifier).attempt(fail: false);

  return seen.firstWhere((state) => state.isLoading && state.hasError);
}

/// Hands the extension a real BuildContext, the way ref.listen does.
Future<void> pumpWith(WidgetTester tester, AsyncValue<void> value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => value.showAlertDialogOnError(context),
            child: const Text('fire'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('fire'));
  await tester.pumpAndSettle();
}

void main() {
  group('shows a dialog', () {
    testWidgets('on an error, with the exception message', (tester) async {
      await pumpWith(
        tester,
        AsyncError<void>(const NetworkException(), StackTrace.empty),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('No connection. Check your network.'), findsOneWidget);
    });

    testWidgets('on an error that is not an AppException', (tester) async {
      await pumpWith(
        tester,
        AsyncError<void>(StateError('bad state'), StackTrace.empty),
      );

      expect(find.textContaining('bad state'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('stays quiet', () {
    testWidgets('on data', (tester) async {
      await pumpWith(tester, const AsyncData<void>(null));

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('on loading', (tester) async {
      await pumpWith(tester, const AsyncLoading<void>());

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('while loading again over an old error', (tester) async {
      // The subtle one, and the reason showAlertDialogOnError checks
      // !isLoading at all. Without that check the user is shown the previous
      // failure the instant they press "try again" — before the retry has had
      // any chance to succeed.
      final retrying = await whileRetryingAfterAFailure();

      expect(retrying.isLoading, isTrue, reason: 'precondition');
      expect(retrying.hasError, isTrue, reason: 'precondition');

      await pumpWith(tester, retrying);

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
