import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Email verification with the 6-digit code from the confirmation email.
///
/// Answers "does this person own this email address?" and nothing else; the
/// church join code is a separate concept handled after sign-in. Supabase
/// issues no session until the code is accepted, so this screen is reached
/// while signed out, from sign-up or from a sign-in that reported an
/// unconfirmed email.
///
/// Provider-neutral wording: it never assumes which mail service the person
/// uses.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  /// Seconds before another code may be requested from this screen.
  static const resendCooldown = 60;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _code = TextEditingController();
  final _email = TextEditingController();

  String? _codeError;
  String? _emailError;
  String? _notice;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _resending = false;

  static const _codeLength = 6;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  /// The address being verified: the one carried over from sign-up or
  /// sign-in, otherwise whatever was typed here after a cold start.
  String? _targetEmail() {
    final pending = ref.read(pendingVerificationProvider);
    if (pending != null && pending.isNotEmpty) return pending;
    final typed = _email.text.trim();
    return typed.isEmpty ? null : typed;
  }

  bool _validateEmailIfNeeded() {
    if (ref.read(pendingVerificationProvider) != null) return true;
    final typed = _email.text.trim();
    setState(() {
      _emailError = typed.isEmpty
          ? 'Enter your email'
          : (!typed.contains('@') ? 'Enter a valid email' : null);
    });
    return _emailError == null;
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    final emailOk = _validateEmailIfNeeded();
    setState(() {
      _codeError = code.length != _codeLength
          ? 'Enter the $_codeLength-digit code'
          : null;
      _notice = null;
    });
    if (!emailOk || _codeError != null) return;

    final email = _targetEmail();
    if (email == null) return;

    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyEmailCode(email: email, code: code);
    if (ok && mounted) {
      // A session now exists; the router takes over. Nothing is left behind
      // for a later visit to this screen.
      ref.read(pendingVerificationProvider.notifier).clear();
    }
  }

  Future<void> _resend() async {
    if (!_validateEmailIfNeeded()) return;
    final email = _targetEmail();
    if (email == null) return;

    setState(() {
      _resending = true;
      _notice = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .resendVerificationCode(email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (ok) {
      ref.read(pendingVerificationProvider.notifier).set(email);
      setState(() => _notice = 'A new code is on its way to $email.');
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = VerifyEmailPage.resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _useDifferentEmail() {
    ref.read(pendingVerificationProvider.notifier).clear();
    ref.read(authControllerProvider.notifier).clearError();
    context.go(Routes.signUp);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final pendingEmail = ref.watch(pendingVerificationProvider);
    final isLoading = auth.isLoading;
    final failure = auth.error;
    final canResend = !isLoading && !_resending && _cooldown == 0;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const BrandMark(),
          const SizedBox(height: AppSpacing.lg),
          Text('Verify your email', style: AppTypography.display),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            pendingEmail == null
                ? 'Enter the email you registered with and the code we sent '
                      'to it.'
                : 'We sent a verification code to $pendingEmail. Enter it '
                      'below to continue.',
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
          ] else if (_notice != null) ...[
            _Notice(message: _notice!),
            const SizedBox(height: AppSpacing.md),
          ],

          if (pendingEmail == null)
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
            label: 'VERIFICATION CODE',
            controller: _code,
            hint: '6-digit code',
            errorText: _codeError,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            enabled: !isLoading,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            textStyle: AppTypography.body.copyWith(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
              ref.read(authControllerProvider.notifier).clearError();
            },
            onSubmitted: (_) => _verify(),
          ),

          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Verify',
            isLoading: isLoading && !_resending,
            onPressed: isLoading ? null : _verify,
          ),
          const SizedBox(height: AppSpacing.md),

          Center(
            child: AppButton(
              label: _cooldown > 0
                  ? 'Resend code (${_cooldown}s)'
                  : 'Resend code',
              variant: AppButtonVariant.secondary,
              expand: false,
              isLoading: _resending,
              onPressed: canResend ? _resend : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: AppButton(
              label: 'Use a different email',
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: isLoading ? null : _useDifferentEmail,
            ),
          ),
          Center(
            child: AppButton(
              label: 'Already verified? Sign in',
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: isLoading
                  ? null
                  : () {
                      ref.read(authControllerProvider.notifier).clearError();
                      context.go(Routes.signIn);
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// A quiet confirmation banner, the counterpart of [InlineError].
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.successSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 18, color: p.success),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.supporting.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
