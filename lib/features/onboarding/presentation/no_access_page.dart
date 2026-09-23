import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../membership/presentation/membership_status_pill.dart';
import '../../profile/application/profile_providers.dart';

/// Shown for INACTIVE, TRANSFERRED or ARCHIVED memberships.
///
/// RBAC_RLS_MATRIX section 1a: no protected church access. A rejected
/// request is ARCHIVED (DATABASE_CONSTRAINTS section 1), and only a
/// controlled reinstatement by the church can reopen it, so this screen has no
/// "request again" action. The profile stays reachable.
class NoAccessPage extends ConsumerWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final membership = ref.watch(myMembershipProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final signingOut = ref.watch(authControllerProvider).isLoading;

    final status = membership?.status;
    final churchName = church?.name ?? 'your church';

    final (title, message) = switch (status) {
      MembershipStatus.archived => (
        'Your request was not approved',
        'Your membership request for $churchName is closed. If you think '
            'this is a mistake, please speak with your church leaders.',
      ),
      MembershipStatus.inactive => (
        'Your membership is inactive',
        'Your access to $churchName is currently inactive. Your church '
            'leaders can reactivate it.',
      ),
      MembershipStatus.transferred => (
        'You have transferred out',
        'Your membership records that you transferred out of $churchName. '
            'Speak with your church leaders if this has changed.',
      ),
      _ => (
        'Access unavailable',
        'Your membership does not currently give access to $churchName. '
            'Please speak with your church leaders.',
      ),
    };

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: 'Your access needs attention',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
            status: MembershipStatusPill(status: status),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(title, style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            fill: AppCardFill.pastel,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.body.copyWith(
                      color: AppCardFill.pastel.foreground(context.palette),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'You can still view and edit your profile.',
            style: context.supportingStyle,
          ),

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.text,
            isLoading: signingOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
