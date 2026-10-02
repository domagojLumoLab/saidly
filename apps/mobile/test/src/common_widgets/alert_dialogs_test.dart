import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/common_widgets/alert_dialogs.dart';
import 'package:saidly/src/exceptions/app_exception.dart';

/// Pumps a screen with one button that opens the dialog, and records what the
/// dialog returned. A dialog needs a Navigator and MaterialLocalizations, so
/// it cannot be pumped on its own.
Future<void> pumpDialog(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showAlertDialog', () {
    testWidgets('shows the title and the content', (tester) async {
      await pumpDialog(
        tester,
        (context) => showAlertDialog(
          context: context,
          title: 'Sign-in failed',
          content: 'Email or password is incorrect.',
        ),
      );

      expect(find.text('Sign-in failed'), findsOneWidget);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('has only a confirm button when no cancel text is given', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        (context) => showAlertDialog(context: context, title: 'Done'),
      );

      expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('returns true when confirmed', (tester) async {
      bool? answer;
      await pumpDialog(tester, (context) async {
        answer = await showAlertDialog(
          context: context,
          title: 'Sign out?',
          cancelActionText: 'Cancel',
        );
      });

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? answer;
      await pumpDialog(tester, (context) async {
        answer = await showAlertDialog(
          context: context,
          title: 'Sign out?',
          cancelActionText: 'Cancel',
        );
      });

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });
  });

  group('showExceptionAlertDialog', () {
    testWidgets('shows AppException.message, never its code', (tester) async {
      await pumpDialog(
        tester,
        (context) => showExceptionAlertDialog(
          context: context,
          title: 'Sign-in failed',
          exception: const UnknownAuthException('quota-exceeded'),
        ),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('quota'), findsNothing);
    });

    testWidgets('an error that is not an AppException still gets a sentence', (
      tester,
    ) async {
      // A TypeError or a StateError from our own code would otherwise reach the
      // screen as "Instance of 'TypeError'". The user gets a sentence and the
      // raw object stays in the logs.
      await pumpDialog(
        tester,
        (context) => showExceptionAlertDialog(
          context: context,
          title: 'Sign-in failed',
          exception: StateError('subscription already cancelled'),
        ),
      );

      expect(find.textContaining('subscription'), findsNothing);
      expect(find.textContaining('Instance of'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
