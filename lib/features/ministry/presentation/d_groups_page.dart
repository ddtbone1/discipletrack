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
import '../../../core/widgets/app_text_link.dart';
import '../../membership/application/membership_providers.dart';
import '../../profile/presentation/member_avatar.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../../../core/connectivity/connection_status.dart';
import '../domain/d_group.dart';
import '../domain/discipler_candidate.dart';
import 'appoint_discipler_dialog.dart';
import 'ministry_ui.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/charts.dart';

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
            // 1. The church at a glance: who is in a group, and as what.
            if (groups.value case final items?)
              _ChurchOverview(groups: items, unplaced: unplaced ?? 0),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'New group',
              requiresConnection: true,
              icon: Icons.add_rounded,
              onPressed: () => context.push(Routes.newDGroup),
            ),

            // 2. The groups.
            const SizedBox(height: AppSpacing.lg),
            SectionHeading(
              groups.value == null
                  ? 'Groups'
                  : 'Groups  ·  ${groups.value!.length}',
              trailing: AppTextLink(
                label: 'Curriculum',
                onTap: () => context.push(Routes.lessons),
              ),
            ),
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
                      illustration: Illustration.group,
                      title: 'No D Groups yet',
                      message:
                          'Create the first group and appoint its Leader. '
                          'The Leader then adds members and sets up who '
                          'disciples whom.',
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
            // 3. People waiting on the Coordinator.
            const SizedBox(height: AppSpacing.lg),
            const _Candidates(),
            const _Unplaced(),

            // 4. The church's setup, last.
            const SizedBox(height: AppSpacing.lg),
            const _SetupPeriodCard(),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// The church at a glance: a ring of every active member by where they
/// are, with the counts beside it.
class _ChurchOverview extends StatelessWidget {
  const _ChurchOverview({required this.groups, required this.unplaced});

  final List<DGroupSummary> groups;
  final int unplaced;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    int sum(int Function(DGroupSummary) f) =>
        groups.fold<int>(0, (t, g) => t + f(g));
    final placed = sum((g) => g.memberCount ?? 0);
    final disciplers = sum((g) => g.disciplerCount);
    final disciples = sum((g) => g.discipleCount);
    return AppCard(
      child: DonutChart(
        centerValue: '${placed + unplaced}',
        centerLabel: 'members',
        slices: [
          (
            value: disciplers,
            color: pillColors(context, PillTone.brand).$2,
            label: 'Disciplers',
          ),
          (value: disciples, color: p.brand, label: 'Disciples'),
          (
            value: unplaced,
            color: pillColors(context, PillTone.warning).$2,
            label: 'Not in a group',
          ),
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
                  [
                    'Led by ${summary.leaderName ?? 'no one'}',
                    // Everyone placed, set up or not (ADR-018).
                    if (summary.memberCount != null)
                      MinistryFormat.count(summary.memberCount!, 'member'),
                  ].join(' · '),
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

/// ACTIVE members in no D Group, so the Coordinator can see who the count on
/// Home refers to. Names only; adding someone happens from a group's page
/// (Add members).
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
                    leading: MemberAvatar(
                      name: m.fullName,
                      membershipId: m.churchMembershipId,
                    ),
                    detail: 'Approved, in no D Group',
                  ),
              ],
            );
          },
        ),
        if (members.value?.any((m) => !m.isPlaced) ?? false) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'To add someone, open a group and tap Add members.',
            style: context.captionStyle,
          ),
        ],
      ],
    );
  }
}

/// The church's initial setup period (Migration 013), for the Coordinator.
///
/// While it is open, Leaders may recognize members who already disciple
/// people in the church as Existing Disciplers when setting them up. Closing
/// it leaves one path to Discipler: Lesson 5, then the Coordinator's
/// appointment. Closing is confirmed; it can be reopened, and both are
/// recorded in the audit log.
class _SetupPeriodCard extends ConsumerWidget {
  const _SetupPeriodCard();

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String churchId, {
    required bool open,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: open ? 'Reopen the setup period?' : 'Close the setup period?',
      message: open
          ? 'Leaders will again be able to set members up as Existing '
                'Disciplers.'
          : 'Leaders will no longer be able to set members up as Existing '
                'Disciplers. From then on, a Disciple becomes a Discipler only '
                'after Lesson 5, when you appoint them. You can reopen it '
                'later.',
      confirmLabel: open ? 'Reopen' : 'Close setup period',
    );
    if (!confirmed) return;
    await ref
        .read(ministryStructureControllerProvider.notifier)
        .setInitialSetupOpen(churchId, open: open);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(initialSetupStatusProvider).value;
    final churchId = ref.watch(myMembershipProvider).value?.churchId;
    final structure = ref.watch(ministryStructureControllerProvider);
    if (status == null || churchId == null) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Initial setup period',
                  style: AppTypography.sectionTitle,
                ),
              ),
              AppPill(
                tone: status.isOpen ? PillTone.brand : PillTone.outline,
                label: status.isOpen ? 'Open' : 'Closed',
                outlined: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            status.isOpen
                ? 'Leaders can set up people who already disciple others in '
                      'the church as Existing Disciplers. Close it once every '
                      'group is set up.'
                : 'Closed ${MinistryFormat.shortDate(status.closedAt!)}. A '
                      'Disciple becomes a Discipler only after Lesson 5, when '
                      'you appoint them.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextLink(
            label: status.isOpen ? 'Close setup period' : 'Reopen',
            requiresConnection: true,
            onTap: structure.isBusy
                ? null
                : () => _toggle(context, ref, churchId, open: !status.isOpen),
          ),
        ],
      ),
    );
  }
}

/// Disciples across the church who are eligible to be appointed as
/// Disciplers and are not yet: what the Coordinator reviews. Eligible is
/// not appointed; nothing happens until the Coordinator appoints. Hidden
/// when nobody is eligible.
class _Candidates extends ConsumerWidget {
  const _Candidates();

  Future<void> _appoint(
    BuildContext context,
    WidgetRef ref,
    DisciplerCandidate c,
  ) async {
    if (!await confirmAppointment(context, c)) return;
    final ok = await ref
        .read(ministryStructureControllerProvider.notifier)
        .appointDiscipler(c.churchMembershipId);
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${c.fullName} is now a Discipler.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(churchDisciplerCandidatesProvider).value;
    final structure = ref.watch(ministryStructureControllerProvider);
    if (candidates == null || candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading('Eligible to disciple'),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              'They completed the lessons needed to disciple others. They '
              'become Disciplers only when you appoint them.',
              style: context.captionStyle,
            ),
          ),
          TileGroup(
            children: [
              for (final c in candidates)
                PersonRow(
                  name: c.fullName,
                  leading: MemberAvatar(
                    name: c.fullName,
                    membershipId: c.churchMembershipId,
                  ),
                  detail:
                      '${c.dGroupName} · eligible since '
                      '${MinistryFormat.shortDate(c.eligibleSince)}',
                  trailing:
                      structure.isRunning('appoint:${c.churchMembershipId}')
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton.tonal(
                          onPressed:
                              structure.isBusy ||
                                  ConnectionScope.isOffline(context)
                              ? null
                              : () => _appoint(context, ref, c),
                          child: const Text('Appoint'),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
