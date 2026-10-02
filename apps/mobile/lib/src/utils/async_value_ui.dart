import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common_widgets/alert_dialogs.dart';
import '../localization/string_hardcoded.dart';

/// The single bridge between a controller's state and an error on screen.
///
/// Used from a widget as
///
/// ```dart
/// ref.listen(someControllerProvider, (_, state) {
///   state.showAlertDialogOnError(context);
/// });
/// ```
///
/// `ref.listen` rather than `ref.watch`, because showing a dialog is an
/// effect: it must happen once per new error, not once per rebuild.
extension AsyncValueUI on AsyncValue<void> {
  void showAlertDialogOnError(BuildContext context) {
    // `!isLoading` is not redundant with `hasError`. When a controller retries,
    // Riverpod keeps the previous AsyncError attached to the new AsyncLoading,
    // so `hasError` is still true while the retry is in flight. Without this
    // check the user would be shown the old failure the moment they press
    // "try again" — before the retry has had a chance to succeed.
    if (!isLoading && hasError) {
      showExceptionAlertDialog(
        context: context,
        title: 'Error'.hardcoded,
        // Safe: hasError is what guarantees it.
        exception: error!,
      );
    }
  }
}
