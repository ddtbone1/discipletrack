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
import '../../../core/widgets/info_group.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../membership/presentation/membership_status_pill.dart';
import '../../membership_review/application/membership_review_providers.dart';
import '../../profile/application/profile_providers.dart';

/// Home for an ACTIVE church member.
///
/// Deliberately thin. The role-aware home in UI_DESIGN_SYSTEM sections 23 to 27
/// carries progress, attendance, attention states and a navigation dock; those
/// arrive with the features that produce the data. This screen shows only
/// facts that actually exist, rather than placeholder metrics standing in for
/// information the database does not yet hold.
///
/// Admins and Coordinators additionally see the membership-request entry
/// point. Showing it is presentation; the database checks the same authority
/// on every approval call.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final canReview = ref.watch(canReviewMembershipsProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;

    final pendingCount = canReview
        ? ref.watch(pendingMembershipRequestsProvider).value?.length
        : null;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: church == null
                ? 'Welcome to your church workspace'
                : 'Welcome to ${church.name}',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
            // The router only sends ACTIVE memberships here.
            status: const MembershipStatusPill(status: MembershipStatus.active),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _JourneyCard(),
          const SizedBox(height: AppSpacing.xl),

          if (canReview) ...[
            InfoGroup(
              title: 'Church',
              rows: [
                InfoRow(
                  label: 'Membership requests',
                  value: pendingCount == null
                      ? null
                      : (pendingCount == 0
                            ? 'None waiting'
                            : '$pendingCount waiting'),
                  icon: Icons.how_to_reg_outlined,
                  onTap: () => context.push(Routes.pendingMembers),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          InfoGroup(
            title: 'Account',
            rows: [
              InfoRow(
                label: 'My profile',
                value: profile?.fullName,
                icon: Icons.person_outline,
                onTap: () => context.go(Routes.profile),
              ),
            ],
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

/// Where the D Group and lesson journey will live. States plainly that the
/// data is not in this build rather than inventing a placeholder number.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.sky;

    return AppCard(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diversity_3_outlined, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Your discipleship journey',
                  style: AppTypography.sectionTitle.copyWith(
                    color: fill.foreground(p),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your D Group, Discipler and lesson progress will show here. '
            'They are not available in this build yet.',
            style: AppTypography.body.copyWith(color: fill.foregroundMuted(p)),
          ),
        ],
      ),
    );
  }
}
