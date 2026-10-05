import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/exceptions/error_handlers.dart';
import 'src/features/authentication/data/auth_repository.dart';

/// Bootstrap, and nothing else.
///
/// The composition root: the one place that touches the outside world and
/// hands it to everything below as an argument. The same shape the API uses in
/// index.ts, and for the same reason — every layer underneath can then be
/// tested without a Firebase, which is what everything under test/ relies on.
Future<void> main() async {
  // Required before any plugin call, including Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  registerErrorHandlers();

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
