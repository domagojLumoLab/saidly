import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/alert_dialogs.dart';
import '../../../common_widgets/async_value_widget.dart';
import '../../../localization/string_hardcoded.dart';
import '../../../utils/async_value_ui.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import 'account_controller.dart';

/// Who is signed in, and the way out.
///
/// Temporary tenant of the `home` route. In 008 the tasks screen takes that
/// route and this becomes `settings`. It lives under `authentication` rather
/// than an invented `features/home/` because what it shows and what it does
/// are both authentication.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const signOutKey = Key('account-signOut');

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAlertDialog(
      context: context,
      title: 'Sign out?'.hardcoded,
      content: "You will need your password to get back in.".hardcoded,
      cancelActionText: 'Cancel'.hardcoded,
      defaultActionText: 'Sign out'.hardcoded,
    );

    // `== true` on purpose: the dialog answers null when it is dismissed by
    // the back button or a tap outside, and that is a no, not a yes.
    if (confirmed == true) {
      await ref.read(accountControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(
      accountControllerProvider,
      (_, state) => state.showAlertDialogOnError(context),
    );
    final signingOut = ref.watch(accountControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text('Account'.hardcoded)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AsyncValueWidget<AppUser?>(
            value: ref.watch(authStateChangesProvider),
            // Null means signed out. The router's redirect is already on its
            // way here, so this is a frame or two of nothing rather than a
            // state worth designing for.
            data: (user) => user == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // On screen because spec 006 is accepted by comparing
                      // this against the userId GET /me answers with. It is
                      // not something a finished app shows a person.
                      Text(
                        'uid ${user.uid}'.hardcoded,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (signingOut)
                        const Center(child: CircularProgressIndicator())
                      else
                        OutlinedButton(
                          key: signOutKey,
                          onPressed: () => _confirmAndSignOut(context, ref),
                          child: Text('Sign out'.hardcoded),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
