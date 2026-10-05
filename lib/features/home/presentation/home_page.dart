import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership_review/application/membership_review_providers.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../ministry/presentation/invitation_card.dart';
import '../../profile/application/profile_providers.dart';
import '../../../core/widgets/empty_state.dart';
import 'group_summary_card.dart';
import 'home_greeting.dart';
import 'journey_blocks.dart';

/// Home for an ACTIVE church member.
///
/// Composed from the person's relationships, not from one role: their D Group
/// entry, their own journey when they are a Disciple, their discipleships
/// when Disciples are paired with them, and church figures for Admins and
/// Coordinators. It shows only facts that exist, never placeholder metrics.
///
/// The ministry entry shows where the person stands in a D Group (or their
/// invitation). Coordinators see the D Groups entry, and Admins and
/// Coordinators the membership-request entry. Showing an entry is
/// presentation; the database checks the same authority on every call.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final canReview = ref.watch(canReviewMembershipsProvider);

    final pendingCount = canReview
        ? ref.watch(pendingMembershipRequestsProvider).value?.length
        : null;
    final isCoordinator = ref.watch(isCoordinatorProvider);
    final groupCount = isCoordinator
        ? ref.watch(dGroupsProvider).value?.length
        : null;
    final unplacedCount = isCoordinator
        ? ref.watch(unplacedMemberCountProvider).value
        : null;
    final activeDiscipleships = isCoordinator
        ? ref.watch(progressSummaryProvider).value?.activeDiscipleships
        : null;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            name: profile?.fullName ?? 'Friend',
            subtitle: church?.name ?? 'Your church workspace',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
          ),
          const SizedBox(height: AppSpacing.xl),

          // A greeting line, then the day's slogan as the body's title.
          HomeGreeting(firstName: profile?.firstName ?? 'friend'),
          const SizedBox(height: AppSpacing.lg),

          const _MinistryEntry(),
          const SizedBox(height: AppSpacing.xl),

          const JourneyBlocks(),

          if (canReview || isCoordinator) ...[
            Semantics(
              header: true,
              child: Text(
                'Church overview',
                style: AppTypography.sectionTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Full-width tiles, one figure each, in the order of plan
            // section F2: requests, not in a group, active discipleships,
            // then D Groups.
            for (final tile in [
              if (canReview)
                StatTile(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Requests',
                  value: pendingCount,
                  supporting: pendingCount == null
                      ? null
                      : pendingCount == 0
                      ? 'No one is waiting to join'
                      : pendingCount == 1
                      ? '1 person waiting to join'
                      : '$pendingCount people waiting to join',
                  onTap: () => context.push(Routes.pendingMembers),
                ),
              if (isCoordinator) ...[
                StatTile(
                  icon: Icons.person_search_outlined,
                  label: 'Not in a group',
                  value: unplacedCount,
                  onTap: () => context.push(Routes.dGroups),
                ),
                StatTile(
                  icon: Icons.handshake_outlined,
                  label: 'Active discipleships',
                  value: activeDiscipleships,
                ),
                StatTile(
                  icon: Icons.groups_2_outlined,
                  label: 'D Groups',
                  value: groupCount,
                  onTap: () => context.push(Routes.dGroups),
                ),
              ],
            ]) ...[tile, const SizedBox(height: AppSpacing.sm)],
            const SizedBox(height: AppSpacing.lg),
          ],

          // Profile and Sign out live on the Profile tab of the dock, not on
          // Home, which shows only the person's current ministry context.
        ],
      ),
    );
  }
}

/// Where the person stands in the ministry structure, as one entry:
///
/// - Leader: a row to their group's detail page.
/// - Discipler or Disciple: a card with their group, Leader and Discipler
///   (or "Not paired yet"), opening the roster.
/// - Invitee: the invitation, with Accept and Decline.
/// - Unplaced: a plain notice; nothing is pretended.
///
/// Lesson progress joins this card with the meeting slice.
class _MinistryEntry extends ConsumerWidget {
  const _MinistryEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministry = ref.watch(myMinistryContextProvider);
    final invitation = ref.watch(myPendingInvitationProvider);

    if (ministry.hasError && !ministry.hasValue) {
      return AppListRow(
        title: 'Could not load your D Group',
        subtitle: 'Tap to try again',
        icon: Icons.refresh_rounded,
        onTap: () => ref
          ..invalidate(myMinistryContextProvider)
          ..invalidate(myPendingInvitationProvider),
      );
    }
    // Nothing yet rather than a guess while the first read is in flight.
    if (!ministry.hasValue) return const SizedBox.shrink();

    final ctx = ministry.value;
    if (ctx == null) {
      final inv = invitation.value;
      if (inv != null) return InvitationCard(invitation: inv);
      if (!invitation.hasValue) return const SizedBox.shrink();
      // An Admin or Coordinator without a D Group role is not waiting to be
      // placed; their Home is about the church, so the card would mislead.
      // Nothing until the roles are known, so an Admin never sees the card
      // flash before their roles arrive.
      if (!ref.watch(myChurchRolesProvider).hasValue ||
          ref.watch(canReviewMembershipsProvider)) {
        return const SizedBox.shrink();
      }
      return const EmptyState(
        title: 'Not placed in a D Group yet',
        message:
            'When a D Group Leader invites you, the invitation appears here '
            'for you to accept.',
      );
    }

    return GroupSummaryCard(ministry: ctx);
  }
}

/// An ACTIVE member with no D Group responsibility and no invitation. A valid
/// state (RBAC section 1, Member Without a D Group), stated plainly.
