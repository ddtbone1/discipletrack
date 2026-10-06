import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/error_state.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../data/remembered_email_store.dart';
import 'auth_form_layout.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _obscure = true;

  // The email of the last person to sign in on this device is filled in;
  // the password comes from the phone's password manager (autofill).
  @override
  void initState() {
    super.initState();
    ref.read(rememberedEmailStoreProvider).read().then((email) {
      if (!mounted || email == null || _email.text.isNotEmpty) return;
      setState(() => _email.text = email);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Client-side validation is for speed of feedback only. The database and
  /// Supabase Auth remain the authority.
  bool _validate() {
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') ? 'Enter a valid email' : null);
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    // Read before the await: on success the router may replace this page.
    final remember = ref.read(rememberedEmailStoreProvider);
    final email = _email.text;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: email, password: _password.text);
    if (ok) {
      // The router redirects on its own. Remember who signed in, and let
      // the password manager save the credentials.
      TextInput.finishAutofillContext();
      await remember.write(email);
      return;
    }
    if (!mounted) return;

    // An account whose email was never verified has no session yet. Send the
    // person to finish verification instead of leaving them at a dead end.
    final failure = ref.read(authControllerProvider).error;
    if (failure is AuthFailure &&
        failure.code == AuthFailureCode.emailNotConfirmed) {
      ref.read(pendingVerificationProvider.notifier).set(_email.text);
      ref.read(authControllerProvider.notifier).clearError();
      context.go(Routes.verifyEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final failure = auth.error;

    return AuthFormLayout(
      title: 'Login',
      subtitle: 'Welcome back. Sign in to continue.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null) ...[
              InlineError(
                message: failure is AuthFailure
                    ? failure.message
                    : 'Something went wrong. Please try again.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            AppTextField(
              label: 'Email',
              pill: true,
              leadingIcon: Icons.mail_outline_rounded,
              controller: _email,
              hint: 'you@example.com',
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              enabled: !isLoading,
            ),
            AppTextField(
              label: 'Password',
              pill: true,
              leadingIcon: Icons.lock_outline_rounded,
              controller: _password,
              hint: 'Your password',
              errorText: _passwordError,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !isLoading,
              onSubmitted: (_) => _submit(),
              trailing: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: context.palette.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Login',
              pill: true,
              isLoading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),

            Center(
              child: AppTextLink(
                prefix: 'Need an account?',
                label: 'Sign up',
                onTap: isLoading ? null : () => context.go(Routes.signUp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
