import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Edits the three columns Migration 003 grants: full_name, phone, avatar_url.
///
/// avatar_url has no UI yet because there is no upload path. Attempting to
/// change anything else is rejected by the database, so this form is a
/// convenience, not the boundary.
class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return AppScaffold(
      title: 'Edit profile',
      showBackButton: true,
      actions: const [
        ThemeModeToggle(size: 40),
        SizedBox(width: AppSpacing.page),
      ],
      scrollable: false,
      child: profileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (profile) => profile == null
            ? const ErrorState(
                title: 'Profile unavailable',
                message: 'We could not find your profile.',
              )
            : _EditForm(profile: profile),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Mirrors `profiles_full_name_not_blank_check` for fast feedback. The
  /// database still rejects a blank name if this is bypassed.
  bool _validate() {
    setState(() {
      _nameError = _fullName.text.trim().isEmpty
          ? 'Your name cannot be empty'
          : null;
    });
    return _nameError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(profileEditControllerProvider.notifier)
        .save(fullName: _fullName.text, phone: _phone.text);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.go(Routes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(profileEditControllerProvider);
    final isSaving = saveState.isLoading;
    final failure = saveState.error;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const AppAvatar(size: 52),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your name is visible to your D Group and leaders.',
                  style: context.supportingStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (failure != null) ...[
            InlineError(
              message: failure is ProfileFailure
                  ? failure.message
                  : 'Could not save your changes.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            label: 'FULL NAME',
            controller: _fullName,
            errorText: _nameError,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            enabled: !isSaving,
          ),
          AppTextField(
            label: 'PHONE (OPTIONAL)',
            controller: _phone,
            hint: '+63 900 000 0000',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            enabled: !isSaving,
            onSubmitted: (_) => _save(),
          ),

          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Save changes',
            isLoading: isSaving,
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed: isSaving ? null : () => context.go(Routes.profile),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
