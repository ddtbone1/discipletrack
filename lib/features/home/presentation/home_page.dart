import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/info_group.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership_review/application/membership_review_providers.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../ministry/domain/ministry_context.dart';
import '../../ministry/presentation/invitation_card.dart';
import '../../profile/application/profile_providers.dart';

/// Home for an ACTIVE church member.
///
/// Deliberately thin. The role-aware home in UI_DESIGN_SYSTEM sections 23 to 27
/// carries progress, attendance and attention states; those
/// arrive with the features that produce the data. This screen shows only
/// facts that actually exist, rather than placeholder metrics standing in for
/// information the database does not yet hold.
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

          // The greeting is the body's title.
          Semantics(
            header: true,
            child: Text(
              '${greetingFor(DateTime.now())}, '
              '${profile?.firstName ?? 'friend'}',
              style: AppTypography.display.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const _MinistryEntry(),
          const SizedBox(height: AppSpacing.xl),

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
            // Full-width tiles, one figure each.
            if (isCoordinator) ...[
              StatTile(
                icon: Icons.groups_2_outlined,
                label: 'D Groups',
                value: groupCount,
                onTap: () => context.push(Routes.dGroups),
              ),
              const SizedBox(height: AppSpacing.sm),
              StatTile(
                icon: Icons.person_search_outlined,
                label: 'Not in a group',
                value: unplacedCount,
                onTap: () => context.push(Routes.dGroups),
              ),
            ],
            if (isCoordinator && canReview)
              const SizedBox(height: AppSpacing.sm),
            if (canReview)
              StatTile(
                icon: Icons.how_to_reg_outlined,
                label: 'Requests',
                value: pendingCount,
                onTap: () => context.push(Routes.pendingMembers),
              ),
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
      return const _NotPlacedCard();
    }

    if (ctx.isLeader) {
      return InfoGroup(
        title: 'My D Group',
        rows: [
          InfoRow(
            label: ctx.dGroupName,
            value: ctx.isDiscipler ? 'Leader and Discipler' : 'Leader',
            icon: Icons.diversity_3_outlined,
            onTap: () => context.push(Routes.dGroupDetailFor(ctx.dGroupId)),
          ),
        ],
      );
    }
    return _MyGroupCard(ministry: ctx);
  }
}

class _MyGroupCard extends StatelessWidget {
  const _MyGroupCard({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.mint;
    final leader = ministry.leader;
    final discipler = ministry.myDiscipler;
    final lines = [
      'Leader: ${leader?.fullName ?? 'none'}',
      if (ministry.isDisciple)
        discipler == null
            ? 'Not paired with a Discipler yet'
            : 'Discipler: ${discipler.fullName}',
      if (ministry.isDiscipler)
        'Your Disciples: ${ministry.myDisciples.isEmpty ? 'none yet' : ministry.myDisciples.length}',
    ];

    return AppCard(
      fill: fill,
      onTap: () => context.push(Routes.myGroup),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diversity_3_outlined, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  ministry.dGroupName,
                  style: AppTypography.sectionTitle.copyWith(
                    color: fill.foreground(p),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fill.foreground(p)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines)
            Text(
              line,
              style: AppTypography.body.copyWith(
                color: fill.foregroundMuted(p),
              ),
            ),
        ],
      ),
    );
  }
}

/// An ACTIVE member with no D Group responsibility and no invitation. A valid
/// state (RBAC section 1, Member Without a D Group), stated plainly.
class _NotPlacedCard extends StatelessWidget {
  const _NotPlacedCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.pastel;

    return AppCard(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not placed in a D Group yet',
            style: AppTypography.sectionTitle.copyWith(
              color: fill.foreground(p),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'When a D Group Leader invites you, the invitation appears here '
            'for you to accept.',
            style: AppTypography.body.copyWith(color: fill.foregroundMuted(p)),
          ),
        ],
      ),
    );
  }
}
