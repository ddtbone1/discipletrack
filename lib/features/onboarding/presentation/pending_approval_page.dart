import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/step_list.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../membership/presentation/membership_status_pill.dart';
import '../../profile/application/profile_providers.dart';

/// Shown while a membership is PENDING.
///
/// Answers "where is my request?".
///
/// RBAC_RLS_MATRIX section 1a: a PENDING member may access only the minimum
/// onboarding state, including their own pending membership row. No church
/// data, announcements, curriculum or member visibility. This screen shows
/// exactly that, and the database enforces the rest.
class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final signingOut = ref.watch(authControllerProvider).isLoading;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: 'Your request is being reviewed',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
            status: const MembershipStatusPill(
              status: MembershipStatus.pending,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Your request', style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.lg),

          StepList(
            steps: [
              const StepItem(
                title: 'Account created',
                state: StepProgress.done,
              ),
              const StepItem(
                title: 'Join request sent',
                state: StepProgress.done,
              ),
              StepItem(
                title: 'Coordinator review',
                subtitle:
                    'Your Coordinator is reviewing your request. There is '
                    'nothing else you need to do.',
                state: StepProgress.current,
              ),
              const StepItem(
                title: 'Access to your church',
                subtitle: 'Your D Group and discipleship journey appear here.',
                state: StepProgress.upcoming,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const AppListRow(
            title: 'Until you are approved',
            subtitle: 'You can view and edit your profile only.',
            icon: Icons.lock_clock_outlined,
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
