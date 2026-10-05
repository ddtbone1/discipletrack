import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_pill.dart';
import '../application/ministry_providers.dart';
import '../domain/d_group.dart';
import 'ministry_ui.dart';
import '../../../core/widgets/empty_state.dart';

/// The Coordinator's list of D Groups, with New group.
///
/// Anyone else who opens `/groups` sees an explanation instead: the list is
/// empty for them by RLS, and the database refuses group creation.
class DGroupsPage extends ConsumerWidget {
  const DGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoordinator = ref.watch(isCoordinatorProvider);
    final groups = ref.watch(dGroupsProvider);
    final unplaced = ref.watch(unplacedMemberCountProvider).value;

    return AppScaffold(
      title: 'D Groups',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (!isCoordinator)
            const EmptyState.restricted(
              message: 'The list of D Groups is for your church Coordinator.',
            )
          else ...[
            if (unplaced != null) ...[
              Text(
                unplaced == 0
                    ? 'Every active member is in a D Group.'
                    : '${MinistryFormat.count(unplaced, 'member')} not in a '
                          'D Group yet.',
                style: context.supportingStyle,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: 'New group',
              requiresConnection: true,
              icon: Icons.add_rounded,
              onPressed: () => context.push(Routes.newDGroup),
            ),
            const SizedBox(height: AppSpacing.lg),
            groups.when(
              loading: () => const SizedBox(height: 240, child: LoadingState()),
              error: (e, _) => SizedBox(
                height: 240,
                child: ErrorState.load(
                  subject: "your church's D Groups",
                  error: e,
                  onRetry: () => ref.invalidate(dGroupsProvider),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      title: 'No D Groups yet',
                      message:
                          'Create the first group and appoint its Leader. '
                          'The Leader can then invite members as Disciplers '
                          'and Disciples.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in items) ...[
                          _GroupCard(summary: s),
                          const SizedBox(height: AppSpacing.cardGap),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Unplaced(),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.summary});

  final DGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => context.push(Routes.dGroupDetailFor(summary.group.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.group.name, style: AppTypography.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  'Led by ${summary.leaderName ?? 'no one'}',
                  style: AppTypography.supporting.copyWith(color: p.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${MinistryFormat.count(summary.disciplerCount, 'Discipler')}'
                  ' · ${MinistryFormat.count(summary.discipleCount, 'Disciple')}',
                  style: AppTypography.supporting.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}

/// ACTIVE members who hold no D Group responsibility, so the Coordinator can
/// see who the count on Home refers to. Names and invitation state only;
/// placing someone happens from a group's page (Invite a member).
class _Unplaced extends ConsumerWidget {
  const _Unplaced();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(placeableMembersProvider(null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading('Not in a D Group'),
        members.when(
          loading: () => const SizedBox(height: 120, child: LoadingState()),
          error: (e, _) => InlineError(
            message: 'Could not load the members who are not in a group.',
          ),
          data: (all) {
            final unplaced = [
              for (final m in all)
                if (!m.isPlaced) m,
            ];
            return TileGroup(
              children: [
                if (unplaced.isEmpty)
                  const PersonRow(
                    name: 'Everyone is placed',
                    detail: 'Every active member is in a D Group.',
                  ),
                for (final m in unplaced)
                  PersonRow(
                    name: m.fullName,
                    detail: m.hasPendingInvitation
                        ? 'Invitation waiting for an answer'
                        : 'Not invited yet',
                    trailing: m.hasPendingInvitation
                        ? const StatusPill(
                            label: 'Invited',
                            tone: StatusTone.waiting,
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (members.value?.any((m) => !m.isPlaced) ?? false) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'To place someone, open a group and tap Invite a member.',
            style: context.captionStyle,
          ),
        ],
      ],
    );
  }
}
