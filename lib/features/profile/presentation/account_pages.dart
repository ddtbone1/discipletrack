import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/password_policy.dart';
import '../../auth/presentation/password_checklist.dart';

/// Shared page frame: a title, one line saying what happens, the form.
class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.title,
    required this.intro,
    required this.children,
  });

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(intro, style: context.supportingStyle),
          const SizedBox(height: AppSpacing.lg),
          ...children,
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Changes the password (user, 2026-10-07: its own page, strong rules).
/// The current password first, then a new one that meets every rule, typed
/// twice. The auth server enforces the same rules.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _againError;
  bool _busy = false;
  bool _show = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = ref.read(currentUserEmailProvider);
    setState(() {
      _currentError = _current.text.isEmpty
          ? 'Enter your current password.'
          : null;
      _nextError = passwordProblem(
        _next.text,
        email: email,
        current: _current.text,
      );
      _againError = _again.text != _next.text
          ? 'The two new passwords do not match.'
          : null;
    });
    if (_currentError != null || _nextError != null || _againError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your password is changed.')),
      );
    } on AuthFailure catch (e) {
      setState(() {
        if (e.code == AuthFailureCode.invalidCredentials) {
          _currentError = 'Your current password is not correct.';
        } else {
          _nextError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eye = IconButton(
      tooltip: _show ? 'Hide passwords' : 'Show passwords',
      icon: Icon(
        _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: p.muted,
      ),
      onPressed: () => setState(() => _show = !_show),
    );
    return _AccountPage(
      title: 'Change password',
      intro: 'Enter your current password, then a new one.',
      children: [
        AppTextField(
          label: 'Current password',
          controller: _current,
          obscureText: !_show,
          errorText: _currentError,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
          trailing: eye,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'New password',
          controller: _next,
          obscureText: !_show,
          errorText: _nextError,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() => _nextError = null),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: PasswordChecklist(password: _next.text),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'New password again',
          controller: _again,
          obscureText: !_show,
          errorText: _againError,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Change password',
          isLoading: _busy,
          requiresConnection: true,
          offlineAction: 'change your password',
          onPressed: isStrongPassword(_next.text) ? _save : null,
        ),
      ],
    );
  }
}
