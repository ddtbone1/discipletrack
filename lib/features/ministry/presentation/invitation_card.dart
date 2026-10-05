import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../application/invitation_response_controller.dart';
import '../domain/d_group_invitation.dart';
import 'ministry_ui.dart';

/// The invitee's view of their pending invitation, with Accept and Decline.
///
/// Joining a group needs the member's own acceptance (Plan decision 3). The
/// database re-checks everything on the call; the card only offers it.
class InvitationCard extends ConsumerWidget {
  const InvitationCard({required this.invitation, this.now, super.key});

  final DGroupInvitation invitation;

  /// Injected by tests; the current time otherwise.
  final DateTime? now;

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Decline this invitation?',
      message:
          '${invitation.invitedByName ?? 'Your inviter'} will see that you '
          'declined, and may invite you again later.',
      confirmLabel: 'Decline',
      cancelLabel: 'Keep invitation',
    );
    if (confirmed) {
      await ref
          .read(invitationResponseControllerProvider.notifier)
          .decline(invitation.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    const fill = AppCardFill.mint;
    final state = ref.watch(invitationResponseControllerProvider);
    final controller = ref.read(invitationResponseControllerProvider.notifier);
    final daysLeft = invitation.daysLeftAt(now ?? DateTime.now());
    final inviter = invitation.invitedByName ?? 'Your church';
    final role = invitation.responsibility.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          fill: fill,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 22),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'You\'re invited to ${invitation.dGroupName ?? 'a D Group'}',
                      style: AppTypography.sectionTitle.copyWith(
                        color: fill.foreground(p),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$inviter invited you to join as a $role. '
                '${MinistryFormat.expiresIn(daysLeft)}.',
                style: AppTypography.body.copyWith(
                  color: fill.foregroundMuted(p),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Accept',
                      requiresConnection: true,
                      icon: Icons.check_rounded,
                      isLoading: state.answering == true,
                      onPressed: state.isBusy
                          ? null
                          : () => controller.accept(invitation.id),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Decline',
                      requiresConnection: true,
                      variant: AppButtonVariant.secondary,
                      isLoading: state.answering == false,
                      onPressed: state.isBusy
                          ? null
                          : () => _decline(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineError(message: state.error!.message),
        ],
      ],
    );
  }
}
