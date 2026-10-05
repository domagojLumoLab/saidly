import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/features/authentication/data/auth_repository.dart';
import 'src/localization/string_hardcoded.dart';

/// Bootstrap, and nothing else.
///
/// The composition root: the one place that touches the outside world and
/// hands it to everything below as an argument. The same shape the API uses in
/// index.ts, and for the same reason — every layer underneath can then be
/// tested without a Firebase, which is what the 103 tests in test/ rely on.
Future<void> main() async {
  // Required before any plugin call, including Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  _registerErrorHandlers();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ProviderScope(
      overrides: [
        // authRepositoryProvider throws by default, so that a test which
        // forgets to override it fails loudly instead of quietly reaching for
        // a Firebase that was never initialised. This is the one place that
        // gives it the real thing.
        authRepositoryProvider.overrideWithValue(
          AuthRepository(FirebaseAuth.instance),
        ),
      ],
      child: const App(),
    ),
  );
}

/// Catches what no widget is in a position to catch.
void _registerErrorHandlers() {
  // Errors thrown while building, laying out or painting a widget.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Errors from outside the widget tree: a Future nobody awaited, a stream
  // with no error handler. Without this they are swallowed in release builds.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error');
    // true means handled. Returning false hands it to the platform, which
    // terminates the app — rarely what a user deserves for a background
    // failure they did not cause.
    return true;
  };

  // Replaces the grey-and-red error box with something a person can read.
  // The default is written for whoever wrote the widget, and in a release
  // build it is a blank grey rectangle, which tells nobody anything.
  ErrorWidget.builder = (details) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Something went wrong on this screen.'.hardcoded,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
