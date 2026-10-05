import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../localization/string_hardcoded.dart';
import '../../../utils/async_value_ui.dart';
import 'sign_in_controller.dart';

/// Email and password, nothing else.
///
/// No Google or Apple sign-in in v0.1: each needs platform configuration and
/// a store review conversation, and neither changes what the API sees — it
/// verifies a Firebase ID token either way. Adding one later does not change
/// `AuthRepository`, this screen, or anything above it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  // Keys rather than text, so tests do not break when the labels move to the
  // .arb file — and so finding the password field does not depend on a label
  // a translator may rewrite.
  static const emailKey = Key('signIn-email');
  static const passwordKey = Key('signIn-password');
  static const submitKey = Key('signIn-submit');

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // `?? false` because currentState is null before the first build. It never
    // is here, but the analyzer cannot know that.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(signInControllerProvider.notifier)
        .signIn(
          // Trimmed: keyboards add a trailing space after autocomplete, and
          // Firebase would reject " a@b.com" as a different address.
          email: _email.text.trim(),
          // NOT trimmed. A space is a legitimate password character, and
          // silently dropping it locks someone out with no way to find out why.
          password: _password.text,
        );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email'.hardcoded;
    // Deliberately loose. Firebase decides what a valid address is; this only
    // catches input that cannot possibly work, to save a round trip.
    if (!email.contains('@')) return 'That is not an email address'.hardcoded;
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password'.hardcoded;
    // Firebase's own minimum. Checking it here puts the message next to the
    // field instead of in a dialog after a failed round trip.
    if (password.length < 6) {
      return 'At least 6 characters'.hardcoded;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // listen, not watch: showing a dialog is an effect that must happen once
    // per new error, not once per rebuild.
    ref.listen<AsyncValue<void>>(
      signInControllerProvider,
      (_, state) => state.showAlertDialogOnError(context),
    );
    final state = ref.watch(signInControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Sign in'.hardcoded)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: SignInScreen.emailKey,
                  controller: _email,
                  decoration: InputDecoration(
                    labelText: 'Email'.hardcoded,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: SignInScreen.passwordKey,
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Password'.hardcoded,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  // Submitting from the keyboard is the same action as the
                  // button, so it goes through the same code path.
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                // The button is replaced by the spinner rather than merely
                // disabled: there is then no second tap to debounce, and no
                // moment where the control looks pressable but is not.
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    key: SignInScreen.submitKey,
                    onPressed: _submit,
                    child: Text('Sign in'.hardcoded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
