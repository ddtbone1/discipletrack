import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_pill.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../discipleship/domain/disciple_progress_summary.dart';
import '../../discipleship/presentation/current_lesson_card.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_invitation.dart';
import '../domain/d_group_member.dart';
import '../domain/member_option.dart';
import 'member_picker_page.dart';
import 'ministry_ui.dart';
import 'pair_sheet.dart';
import '../../../core/widgets/empty_state.dart';

/// One D Group, for its Coordinator (any group) and its Leader (their own).
///
/// Sections: Leader, Disciplers with their Disciples, Disciples with their
/// pairing, invitations, and the invite action. Which actions appear depends
/// on who is looking (Plan section B); the database enforces the same rules
/// on every call, so a hidden action is a courtesy, not the protection.
///
/// Anyone else who reaches this route (a deep link) gets a refusal, because
/// RLS returns no group to them.
class DGroupDetailPage extends ConsumerWidget {
  const DGroupDetailPage({required this.groupId, this.now, super.key});

  final String groupId;

  /// Injected by tests; the current time otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dGroupDetailProvider(groupId));
    final structure = ref.watch(ministryStructureControllerProvider);

    return AppScaffold(
      title: detail.value?.group.name ?? 'D Group',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (structure.error != null) ...[
            InlineError(message: structure.error!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          detail.when(
            // Keep showing the previous detail while a refresh after an
            // action is in flight, rather than tearing the page down.
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => SizedBox(
              height: 320,
              child: ErrorState.load(
                subject: 'this D Group',
                error: e,
                onRetry: () => ref.invalidate(dGroupDetailProvider(groupId)),
              ),
            ),
            data: (d) => d == null
                ? const EmptyState.restricted(
                    title: "This D Group isn't available",
                    message:
                        "Only the church Coordinator and the group's Leader "
                        "can open a D Group's details.",
                  )
                : _DetailBody(detail: d, now: now ?? DateTime.now()),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.now});

  final DGroupDetail detail;
  final DateTime now;

  String get _groupId => detail.group.id;

  Future<void> _changeLeader(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.of(context).push<MemberOption>(
      MaterialPageRoute(
        builder: (_) => MemberPickerPage(
          purpose: MemberPickPurpose.appointLeader,
          groupId: _groupId,
          title: 'Choose the new Leader',
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    final current = detail.leader?.fullName ?? 'The current Leader';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Make ${picked.fullName} the Leader?',
      message:
          '$current will no longer lead ${detail.group.name}. If they are '
          'not also a Discipler here, they will no longer be in the group.',
      confirmLabel: 'Change Leader',
    );
    if (confirmed) {
      await ref
          .read(ministryStructureControllerProvider.notifier)
          .assignLeader(_groupId, picked.churchMembershipId);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    DGroupMember member,
  ) async {
    final pairings = member.responsibility == DGroupResponsibility.discipler
        ? detail.disciplesOf(member).length
        : 0;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${member.fullName}?',
      message: [
        'They will no longer be a ${member.responsibility.label} in '
            '${detail.group.name}. Their history is kept.',
        if (pairings > 0)
          '${MinistryFormat.count(pairings, 'Disciple')} paired with them '
              'will be unpaired.',
      ].join(' '),
      confirmLabel: 'Remove',
    );
    if (confirmed) {
      await ref
          .read(ministryStructureControllerProvider.notifier)
          .endMembership(member.dGroupMembershipId);
    }
  }

  Future<void> _pair(
    BuildContext context,
    WidgetRef ref,
    DGroupMember disciple,
  ) async {
    final selection = await showPairSheet(
      context,
      detail: detail,
      disciple: disciple,
    );
    if (selection == null || !context.mounted) return;
    // UI_DESIGN_SYSTEM section 45: removing an assignment is confirmed.
    if (selection.disciplerDGroupMembershipId == null) {
      final current = detail.disciplerOf(disciple);
      final confirmed = await showConfirmDialog(
        context,
        title: 'Unpair ${disciple.fullName}?',
        message:
            '${disciple.fullName} will have no Discipler until you pair them '
            'again. ${current?.fullName ?? 'Their Discipler'} keeps their '
            'history with them.',
        confirmLabel: 'Unpair',
      );
      if (!confirmed) return;
    }
    await ref
        .read(ministryStructureControllerProvider.notifier)
        .setDiscipler(
          disciple.dGroupMembershipId,
          selection.disciplerDGroupMembershipId,
        );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    DGroupInvitation invitation,
  ) async {
    // No confirmation: a withdrawn invitation can simply be sent again.
    await ref
        .read(ministryStructureControllerProvider.notifier)
        .withdrawInvitation(invitation.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final structure = ref.watch(ministryStructureControllerProvider);
    final controller = ref.read(ministryStructureControllerProvider.notifier);
    final isCoordinator = ref.watch(isCoordinatorProvider);
    final myContext = ref.watch(myMinistryContextProvider).value;
    final isLeaderHere =
        myContext != null &&
        myContext.isLeader &&
        myContext.dGroupId == _groupId;
    final myUserId = ref.watch(currentUserIdProvider);
    final canManage = isCoordinator || isLeaderHere;
    // Members' progress, for the group's Leader and the Coordinator only
    // (step 8). Rows fall back to plain faces while it loads or if refused.
    final progress = canManage
        ? ref.watch(groupProgressProvider(_groupId)).value
        : null;

    final leader = detail.leader;
    final disciplers = detail.disciplers;
    final disciples = detail.disciples;
    final open = detail.openInvitationsAt(now);
    final closed = detail.closedInvitationsAt(now);

    Widget? overflow(List<(String, VoidCallback)> items) {
      if (!canManage || items.isEmpty) return null;
      return PopupMenuButton<int>(
        tooltip: 'More actions',
        enabled: !structure.isBusy && !ConnectionScope.isOffline(context),
        icon: Icon(Icons.more_vert_rounded, color: p.muted),
        onSelected: (i) => items[i].$2(),
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem(value: i, child: Text(items[i].$1)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.group.description != null) ...[
          Text(detail.group.description!, style: context.supportingStyle),
          const SizedBox(height: AppSpacing.md),
        ],

        // The one primary action, placed first so it is the most prominent
        // element on the page (UI_DESIGN_SYSTEM section 40).
        if (canManage) ...[
          AppButton(
            label: 'Invite a member',
            requiresConnection: true,
            icon: Icons.person_add_alt_outlined,
            onPressed: structure.isBusy
                ? null
                : () => context.push(Routes.dGroupInviteFor(_groupId)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Leader --------------------------------------------------------
        SectionHeading(
          'Leader',
          trailing: isCoordinator
              ? AppTextLink(
                  label: 'Change Leader',
                  requiresConnection: true,
                  onTap: structure.isBusy
                      ? null
                      : () => _changeLeader(context, ref),
                )
              : null,
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: PersonRow(
            name: leader?.fullName ?? 'No Leader',
            leading: leader == null
                ? null
                : InitialsAvatar(name: leader.fullName),
            detail: leader?.phone,
            pills: [
              if (leader != null)
                const AppPill(
                  tone: PillTone.brand,
                  icon: Icons.star_rounded,
                  label: 'Leader',
                ),
              if (detail.leaderIsDiscipler)
                const AppPill(
                  icon: Icons.school_outlined,
                  label: 'Also a Discipler',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Disciplers -----------------------------------------------------
        SectionHeading('Disciplers'),
        TileGroup(
          children: [
            if (disciplers.isEmpty)
              const PersonRow(
                name: 'No Disciplers yet',
                detail: 'Invite someone as a Discipler, then pair them with Disciples.',
              ),
            for (final d in disciplers)
              PersonRow(
                name: d.fullName,
                leading: InitialsAvatar(name: d.fullName),
                detail: _disciplesLine(detail.disciplesOf(d)),
                pills: [
                  const AppPill(
                    icon: Icons.school_outlined,
                    label: 'Discipler',
                  ),
                  if (detail.disciplesOf(d).isEmpty)
                    const AppPill(
                      tone: PillTone.warning,
                      label: 'No Disciples yet',
                    )
                  else
                    AppPill(
                      label: detail.disciplesOf(d).length == 1
                          ? '1 Disciple'
                          : '${detail.disciplesOf(d).length} Disciples',
                    ),
                ],
                trailing: overflow([
                  ('Remove from group', () => _remove(context, ref, d)),
                ]),
              ),
          ],
        ),
        if (isLeaderHere && !detail.leaderIsDiscipler) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Add myself as Discipler',
            requiresConnection: true,
            variant: AppButtonVariant.secondary,
            icon: Icons.person_add_alt_1_outlined,
            isLoading: structure.isRunning('self:$_groupId'),
            onPressed: structure.isBusy
                ? null
                : () => controller.addSelfAsDiscipler(_groupId),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        // Disciples ------------------------------------------------------
        SectionHeading('Disciples'),
        if (disciples.isNotEmpty) ...[
          PairingProgress(
            paired: disciples
                .where((d) => detail.disciplerOf(d) != null)
                .length,
            total: disciples.length,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TileGroup(
          children: [
            if (disciples.isEmpty)
              const PersonRow(
                name: 'No Disciples yet',
                detail:
                    'Invite members as Disciples. They join once they accept.',
              ),
            for (final d in [
              ...disciples.where((d) => detail.disciplerOf(d) == null),
              ...disciples.where((d) => detail.disciplerOf(d) != null),
            ])
              _DiscipleRow(
                disciple: d,
                discipler: detail.disciplerOf(d),
                progress: progress?[d.churchMembershipId],
                canManage: canManage,
                busy: structure.isRunning('pair:${d.dGroupMembershipId}'),
                enabled: !structure.isBusy,
                onPair: () => _pair(context, ref, d),
                overflow: overflow([
                  ('Remove from group', () => _remove(context, ref, d)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Invitations ----------------------------------------------------
        if (canManage) ...[
          SectionHeading('Invitations'),
          TileGroup(
            children: [
              if (open.isEmpty && closed.isEmpty)
                const PersonRow(
                  name: 'No invitations waiting',
                  detail: 'People you invite show up here until they answer.',
                ),
              for (final i in open)
                PersonRow(
                  name: i.inviteeName ?? 'Unnamed member',
                  detail:
                      '${i.responsibility.label} · '
                      '${MinistryFormat.expiresIn(i.daysLeftAt(now))}',
                  trailing:
                      (isCoordinator ||
                          (isLeaderHere && i.invitedBy == myUserId))
                      ? AppTextLink(
                          label: 'Withdraw',
                          requiresConnection: true,
                          onTap: structure.isBusy
                              ? null
                              : () => _withdraw(context, ref, i),
                        )
                      : const StatusPill(
                          label: 'Pending',
                          tone: StatusTone.waiting,
                        ),
                ),
              for (final i in closed)
                PersonRow(
                  name: i.inviteeName ?? 'Unnamed member',
                  detail:
                      '${i.responsibility.label} · '
                      '${i.statusAt(now) == DGroupInvitationStatus.declined ? 'Declined' : 'Expired'}'
                      ' ${MinistryFormat.shortDate(i.respondedAt ?? i.expiresAt)}',
                  trailing: AppTextLink(
                    label: 'Invite again',
                    requiresConnection: true,
                    onTap: structure.isBusy || i.churchMembershipId == null
                        ? null
                        : () => controller.invite(
                            _groupId,
                            i.churchMembershipId!,
                            i.responsibility,
                          ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _disciplesLine(List<DGroupMember> disciples) {
    if (disciples.isEmpty) return 'No Disciples paired yet';
    return disciples.map((d) => d.fullName).join(', ');
  }
}

class _DiscipleRow extends StatelessWidget {
  const _DiscipleRow({
    required this.disciple,
    required this.discipler,
    this.progress,
    required this.canManage,
    required this.busy,
    required this.enabled,
    required this.onPair,
    required this.overflow,
  });

  final DGroupMember disciple;
  final DGroupMember? discipler;

  /// The Disciple's progress, when the viewer may see it.
  final DiscipleProgressSummary? progress;
  final bool canManage;
  final bool busy;
  final bool enabled;
  final VoidCallback onPair;
  final Widget? overflow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final paired = discipler != null;

    final Widget action;
    if (!canManage) {
      action = const SizedBox.shrink();
    } else if (busy) {
      action = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (paired) {
      action = TextButton(
        onPressed: enabled ? onPair : null,
        child: const Text('Change'),
      );
    } else {
      // Unpaired is the state that needs action, so its action stands out.
      action = FilledButton.tonalIcon(
        onPressed: enabled ? onPair : null,
        icon: const Icon(Icons.link_rounded, size: 18),
        label: const Text('Pair'),
      );
    }

    return InkWell(
      onTap: () =>
          context.push(Routes.discipleDetailFor(disciple.churchMembershipId)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (progress == null)
              InitialsAvatar(name: disciple.fullName)
            else
              LessonRing(
                total: progress!.lessonsTotal,
                completed: progress!.lessonsCompleted,
                currentNumber: progress!.currentLessonNumber,
                size: 44,
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disciple.fullName,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (progress != null)
                    Text(
                      progress!.lessonLine,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (paired)
                    Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Paired with ${discipler!.fullName}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const AppPill(
                      tone: PillTone.warning,
                      icon: Icons.link_off_rounded,
                      label: 'Not paired yet',
                    ),
                ],
              ),
            ),
            action,
            ?overflow,
          ],
        ),
      ),
    );
  }
}
