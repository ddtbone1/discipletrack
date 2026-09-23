import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/error_state.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

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
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    // On success the router redirects automatically; no imperative navigation.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final failure = auth.error;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const BrandMark(),
          const SizedBox(height: AppSpacing.lg),
          Text('Welcome back', style: AppTypography.display),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Sign in to continue your discipleship journey.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.xl),

          if (failure != null) ...[
            InlineError(
              message: failure is AuthFailure
                  ? failure.message
                  : 'Something went wrong. Please try again.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            label: 'EMAIL',
            controller: _email,
            hint: 'you@example.com',
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !isLoading,
          ),
          AppTextField(
            label: 'PASSWORD',
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
          AppButton(label: 'Sign in', isLoading: isLoading, onPressed: _submit),
          const SizedBox(height: AppSpacing.md),

          Center(
            child: AppButton(
              label: "New here? Create an account",
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: isLoading ? null : () => context.go(Routes.signUp),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
