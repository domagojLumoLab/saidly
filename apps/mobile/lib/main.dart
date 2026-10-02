import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder. The real bootstrap — Firebase.initializeApp, the error
/// handlers and MaterialApp.router — is the last step of spec 006, once
/// app_router.dart and app.dart exist for it to start.
///
/// It is written out rather than left as the `flutter create` sample so the
/// tree passes `dart analyze --fatal-infos`: without the ProviderScope,
/// riverpod_lint reports missing_provider_scope, and a warning that is always
/// there is a warning nobody reads.
void main() {
  runApp(const ProviderScope(child: _UnderConstruction()));
}

class _UnderConstruction extends StatelessWidget {
  const _UnderConstruction();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Saidly — shell under construction')),
      ),
    );
  }
}
