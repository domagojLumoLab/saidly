import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../localization/string_hardcoded.dart';

/// Where a caught error goes. Injected so tests can see what was reported
/// without reading the console, and so a crash reporter can replace it later
/// without this file changing.
typedef ErrorLogger = void Function(String message);

void _toConsole(String message) => debugPrint(message);

/// Installs the three handlers nothing below the widget tree can install.
///
/// Called from main.dart before anything else, including Firebase: an error
/// during initialisation is exactly the kind this exists to catch.
void registerErrorHandlers({ErrorLogger log = _toConsole}) {
  // Thrown while building, laying out or painting a widget.
  FlutterError.onError = (details) {
    // presentError first, so the console still gets the full details and the
    // stack trace; `log` is the short line meant for a human or a reporter.
    FlutterError.presentError(details);
    log('FlutterError: ${details.exceptionAsString()}');
  };

  // From outside the widget tree: a Future nobody awaited, a stream with no
  // error handler. Without this they vanish silently in a release build.
  PlatformDispatcher.instance.onError = (error, stack) {
    log('Uncaught: $error');
    // true means handled. Returning false hands the error to the platform,
    // which terminates the process — rarely what a person deserves for a
    // background failure they did not cause.
    return true;
  };

  ErrorWidget.builder = _buildErrorScreen;
}

/// Replaces the default error box.
///
/// The default prints the exception and the widget that threw it, which is
/// written for whoever wrote the widget; in a release build it degrades to a
/// blank grey rectangle, which tells nobody anything.
///
/// Deliberately built from `widgets.dart` only — no Scaffold, no Theme, an
/// explicit Directionality. An error thrown while building MaterialApp itself
/// leaves none of those in scope, and a screen that throws while reporting an
/// error is worse than no screen at all.
Widget _buildErrorScreen(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFFF7F7F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong on this screen.'.hardcoded,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
          ),
        ),
      ),
    ),
  );
}
