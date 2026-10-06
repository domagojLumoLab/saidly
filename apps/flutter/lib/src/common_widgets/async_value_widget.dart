import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/app_exception.dart';

/// Renders read-only async data: the value, a spinner, or a message.
///
/// Used with `ref.watch` on a provider a screen only reads. Failures that
/// happen *because the user did something* belong in a dialog instead — see
/// `AsyncValueUI.showAlertDialogOnError` — because an error that replaces the
/// whole screen also removes the form the person was filling in.
///
/// Generic in `T`, including nullable ones: a screen behind the auth guard
/// watches `AsyncValue<AppUser?>`, where null is an ordinary value and not an
/// absence of data.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      // The stack trace is deliberately dropped here, not logged away — it
      // reaches the error handlers in main.dart through the provider itself.
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            messageForUser(error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
