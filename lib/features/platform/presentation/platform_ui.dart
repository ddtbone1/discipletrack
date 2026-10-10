import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_pill.dart';
import '../../membership/domain/church_membership.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

/// A church's status as a pill: Active, Suspended or Archived.
class ChurchStatusPill extends StatelessWidget {
  const ChurchStatusPill({required this.status, super.key});

  final ChurchStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    ChurchStatus.active => const StatusPill(
      label: 'Active',
      tone: StatusTone.positive,
    ),
    ChurchStatus.suspended => const StatusPill(
      label: 'Suspended',
      tone: StatusTone.waiting,
    ),
    ChurchStatus.archived => const StatusPill(
      label: 'Archived',
      tone: StatusTone.neutral,
    ),
  };
}

/// The confirmation step for every Coordinator change (ADR-022 decision 8):
/// an email, then a sheet naming the account it belongs to, so a mistyped
/// email is caught before anything changes.
///
/// [question] phrases the confirmation for the person found. Resolves the
/// confirmed email, or null when cancelled. Nothing is changed here; the
/// caller runs the operation, and the database checks everything again.
Future<String?> confirmCoordinatorAccount(
  BuildContext context, {
  required String? churchId,
  required String title,
  required String confirmLabel,
  required String Function(String fullName, String email) question,
}) => showModalBottomSheet<String>(
  context: context,
  // Above the dock, like every sheet in the app.
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CoordinatorSheet(
    churchId: churchId,
    title: title,
    confirmLabel: confirmLabel,
    question: question,
  ),
);

class _CoordinatorSheet extends ConsumerStatefulWidget {
  const _CoordinatorSheet({
    required this.churchId,
    required this.title,
    required this.confirmLabel,
    required this.question,
  });

  final String? churchId;
  final String title;
  final String confirmLabel;
  final String Function(String fullName, String email) question;

  @override
  ConsumerState<_CoordinatorSheet> createState() => _CoordinatorSheetState();
}

class _CoordinatorSheetState extends ConsumerState<_CoordinatorSheet> {
  final _email = TextEditingController();
  AccountPreview? _found;
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email they signed up with.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(platformRepositoryProvider)
          .previewAccount(widget.churchId, email);
      setState(() {
        _found = preview.problem == null ? preview : null;
        _error = preview.problem;
      });
    } on PlatformFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        // Clear of the keyboard and of the system gesture bar.
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'They must already have a DiscipleTrack account. No invitation '
            'is sent.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          if (found == null) ...[
            AppTextField(
              label: 'Their email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _check(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InlineError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Continue',
              isLoading: _checking,
              requiresConnection: true,
              offlineAction: 'check this email',
              onPressed: _check,
            ),
          ] else ...[
            Text(
              widget.question(
                found.fullName ?? 'This person',
                _email.text.trim(),
              ),
              style: AppTypography.body.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: widget.confirmLabel,
              requiresConnection: true,
              offlineAction: 'make this change',
              onPressed: () => Navigator.of(context).pop(_email.text.trim()),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Not this person',
              variant: AppButtonVariant.text,
              onPressed: () => setState(() => _found = null),
            ),
          ],
        ],
      ),
    );
  }
}
