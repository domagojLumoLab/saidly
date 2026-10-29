import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saidly/src/exceptions/error_handlers.dart';

void main() {
  // These handlers are global. Without restoring them, one test would change
  // how every later test in the run reports its own failures.
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorWidgetBuilder originalErrorWidgetBuilder;
  late bool Function(Object, StackTrace)? originalPlatformOnError;

  setUp(() {
    originalFlutterOnError = FlutterError.onError;
    originalErrorWidgetBuilder = ErrorWidget.builder;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterOnError;
    ErrorWidget.builder = originalErrorWidgetBuilder;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  group('errors from inside the widget tree', () {
    test('are logged', () {
      final logged = <String>[];
      registerErrorHandlers(log: logged.add);

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('widget blew up')),
      );

      expect(logged, hasLength(1));
      expect(logged.single, contains('widget blew up'));
    });
  });

  group('errors from outside it', () {
    test('are logged', () {
      final logged = <String>[];
      registerErrorHandlers(log: logged.add);

      PlatformDispatcher.instance.onError!(
        StateError('unawaited future'),
        StackTrace.empty,
      );

      expect(logged.single, contains('unawaited future'));
    });

    test('are reported as handled, so the app is not killed', () {
      // Returning false hands the error to the platform, which terminates the
      // process. A background failure the user did not cause should not close
      // their app.
      registerErrorHandlers(log: (_) {});

      final handled = PlatformDispatcher.instance.onError!(
        StateError('boom'),
        StackTrace.empty,
      );

      expect(handled, isTrue);
    });
  });

  group('the error screen', () {
    testWidgets('says something a person can read', (tester) async {
      registerErrorHandlers(log: (_) {});

      await tester.pumpWidget(
        ErrorWidget.builder(
          FlutterErrorDetails(exception: StateError('internal detail')),
        ),
      );

      expect(find.textContaining('went wrong'), findsOneWidget);
    });

    testWidgets('never shows the exception itself', (tester) async {
      // The default red box prints the exception and the widget that threw.
      // That is written for whoever wrote the widget, and in release builds it
      // is a blank grey rectangle that tells nobody anything.
      registerErrorHandlers(log: (_) {});

      await tester.pumpWidget(
        ErrorWidget.builder(
          FlutterErrorDetails(exception: StateError('internal detail')),
        ),
      );

      expect(find.textContaining('internal detail'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('renders without a MaterialApp above it', (tester) async {
      // It has to: an error thrown while building MaterialApp itself leaves
      // no Directionality, no Material and no theme. A Scaffold here would
      // throw while reporting the error it exists to report.
      registerErrorHandlers(log: (_) {});

      await tester.pumpWidget(
        ErrorWidget.builder(FlutterErrorDetails(exception: Exception('x'))),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
