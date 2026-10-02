import 'package:flutter/material.dart';
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
import 'auth_form_layout.dart';

/// Registration.
///
/// Full name is collected here and passed through Supabase Auth metadata. The
/// `handle_new_user` trigger reads it to create the profiles row. This screen
/// never inserts into `profiles`, and the database rejects a blank name
/// independently of the validation below.
///
/// With email confirmation on, a successful sign-up issues no session. The
/// person is taken to the verification screen with their address, and the
/// router only admits them once the code is accepted.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  bool _alreadyRegistered = false;
  bool _obscure = true;

  /// Matches `auth.minimum_password_length` in supabase/config.toml.
  static const _minPasswordLength = 6;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _fullName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _nameError = name.isEmpty ? 'Enter your full name' : null;
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') ? 'Enter a valid email' : null);
      _passwordError = password.length < _minPasswordLength
          ? 'Use at least $_minPasswordLength characters'
          : null;
      _alreadyRegistered = false;
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    final outcome = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
        );
    if (!mounted) return;

    switch (outcome) {
      case SignUpVerificationRequired(:final email):
        ref.read(pendingVerificationProvider.notifier).set(email);
        context.go(Routes.verifyEmail);
      case SignUpAlreadyRegistered():
        // Stays here whether or not the existing account was verified. An
        // unverified owner finishes by signing in with their original
        // password, which routes to verification.
        setState(() => _alreadyRegistered = true);
      case SignUpSignedIn():
      case null:
        // A session appeared (the router redirects) or the controller holds
        // the failure for the banner below.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final failure = auth.error;

    return AuthFormLayout(
      title: 'Sign up',
      subtitle: 'Your name is how your D Group will know you.',
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
          ] else if (_alreadyRegistered) ...[
            const InlineError(
              message:
                  'An account with this email already exists. Login '
                  'instead.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppTextLink(
                label: 'Login',
                onTap: isLoading ? null : () => context.go(Routes.signIn),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          AppTextField(
            label: 'Full name',
            pill: true,
            leadingIcon: Icons.person_outline_rounded,
            controller: _fullName,
            hint: 'Juan dela Cruz',
            errorText: _nameError,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            enabled: !isLoading,
          ),
          AppTextField(
            label: 'Email',
            pill: true,
            leadingIcon: Icons.mail_outline_rounded,
            controller: _email,
            hint: 'you@example.com',
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !isLoading,
          ),
          AppTextField(
            label: 'Password',
            pill: true,
            leadingIcon: Icons.lock_outline_rounded,
            controller: _password,
            hint: 'Create a password',
            errorText: _passwordError,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
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
            label: 'Create account',
            pill: true,
            isLoading: isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: AppTextLink(
              prefix: 'Already have an account?',
              label: 'Login',
              onTap: isLoading ? null : () => context.go(Routes.signIn),
            ),
          ),
        ],
      ),
    );
  }
}
