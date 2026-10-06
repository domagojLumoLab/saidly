import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/common_widgets/async_value_widget.dart';
import 'package:saidly/src/exceptions/app_exception.dart';

Future<void> pumpWith<T>(WidgetTester tester, AsyncValue<T> value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AsyncValueWidget<T>(
          value: value,
          data: (data) => Text('got: $data'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('data builds the child with the value', (tester) async {
    await pumpWith(tester, const AsyncData<String>('tomorrow'));

    expect(find.text('got: tomorrow'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading shows a spinner and not the child', (tester) async {
    await pumpWith(tester, const AsyncLoading<String>());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('got:'), findsNothing);
  });

  testWidgets('an AppException shows its own message', (tester) async {
    await pumpWith(
      tester,
      AsyncError<String>(const NetworkException(), StackTrace.empty),
    );

    expect(find.text('No connection. Check your network.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('anything else shows a sentence, never the object', (
    tester,
  ) async {
    await pumpWith(
      tester,
      AsyncError<String>(
        StateError('subscription cancelled'),
        StackTrace.empty,
      ),
    );

    expect(find.textContaining('subscription'), findsNothing);
    expect(find.textContaining('Instance of'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('works for any T, including a nullable one', (tester) async {
    // The screen behind the auth guard watches AsyncValue<AppUser?>, so null
    // has to be an ordinary value here and not mistaken for "no data".
    await pumpWith(tester, const AsyncData<String?>(null));

    expect(find.text('got: null'), findsOneWidget);
  });
}
