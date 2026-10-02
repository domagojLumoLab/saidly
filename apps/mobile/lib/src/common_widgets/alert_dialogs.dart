import 'package:flutter/material.dart';

import '../exceptions/app_exception.dart';
import '../localization/string_hardcoded.dart';

/// The only alert dialog in the app.
///
/// Returns true when confirmed, false when cancelled, and null when dismissed
/// some other way — so a caller that only cares about confirmation can write
/// `if (await showAlertDialog(...) == true)` and treat both other outcomes as
/// no.
Future<bool?> showAlertDialog({
  required BuildContext context,
  required String title,
  String? content,
  String? cancelActionText,
  String? defaultActionText,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: content != null ? Text(content) : null,
      actions: <Widget>[
        // Cancel is omitted unless asked for, so an error dialog — which has
        // nothing to cancel — does not grow a pointless second button.
        if (cancelActionText != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelActionText),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(defaultActionText ?? 'OK'.hardcoded),
        ),
      ],
    ),
  );
}

/// Shows an error to a person.
///
/// The one place that decides what an arbitrary thrown object looks like on
/// screen. An `AppException` already carries a sentence written for a reader;
/// anything else is one of our own bugs — a `TypeError`, a `StateError` — and
/// its `toString()` is a developer's sentence, so it is replaced. The object
/// itself still reaches the logs; only the screen is protected from it.
Future<void> showExceptionAlertDialog({
  required BuildContext context,
  required String title,
  required Object exception,
}) {
  final message = exception is AppException
      ? exception.message
      : 'Something went wrong. Please try again.'.hardcoded;

  return showAlertDialog(context: context, title: title, content: message);
}
