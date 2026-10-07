import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/role_badge.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../discipleship/domain/disciple_progress_summary.dart';
import '../../profile/presentation/member_avatar.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_member.dart';
import '../domain/discipler_candidate.dart';
import '../domain/member_option.dart';
import 'member_picker_page.dart';
import 'appoint_discipler_dialog.dart';
import 'member_setup_sheet.dart';
import 'ministry_ui.dart';
import 'pair_sheet.dart';

/// One D Group, for its Coordinator (any group) and its Leader (their own):
/// the group's workspace.
///
/// The Leader card, then everyone else in one list with local filters (All,
/// Disciples, Disciplers, Needs setup). Each row carries what the viewer
/// needs to act on: role, pairing, progress where already visible, and the
/// one action that moves the person forward (Set up, Pair). Less frequent
/// actions sit in the row's menu. Which actions appear depends on who is
/// looking; the database enforces the same rules on every call, so a hidden
/// action is a courtesy, not the protection.
///
/// Anyone else who reaches this route (a deep link) gets a refusal, because
/// RLS returns no group to them.
class DGroupDetailPage extends ConsumerWidget {
  const DGroupDetailPage({required this.groupId, super.key});

  final String groupId;

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
                : _DetailBody(detail: d),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.detail});

  final DGroupDetail detail;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  GroupFilter _filter = GroupFilter.all;

  DGroupDetail get detail => widget.detail;
  String get _groupId => detail.group.id;
  MinistryStructureController get _controller =>
      ref.read(ministryStructureControllerProvider.notifier);

  Future<void> _addMembers() async {
    final added = await context.push<int>(Routes.dGroupAddMembersFor(_groupId));
    if (!mounted || added == null || added == 0) return;
    // Show the people just added, who all need setup.
    setState(() => _filter = GroupFilter.needsSetup);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 1
              ? 'Added 1 person. Set up their role next.'
              : 'Added $added people. Set up their roles next.',
        ),
      ),
    );
  }

  Future<void> _changeLeader() async {
    final picked = await Navigator.of(context).push<MemberOption>(
      MaterialPageRoute(
        builder: (_) => MemberPickerPage(
          purpose: MemberPickPurpose.appointLeader,
          groupId: _groupId,
          title: 'Choose the new Leader',
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final current = detail.leader?.fullName ?? 'The current Leader';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Make ${picked.fullName} the Leader?',
      message:
          '$current will no longer lead ${detail.group.name}. If they are '
          'not also a Discipler here, they will leave the group.',
      confirmLabel: 'Change Leader',
    );
    if (!confirmed) return;
    await _controller.assignLeader(_groupId, picked.churchMembershipId);
  }

  Future<void> _setUp(GroupPerson person, {required bool setupOpen}) async {
    final choice = await showMemberSetupSheet(
      context,
      name: person.fullName,
      offerDisciple: !person.isDisciple && !person.isLeader,
      offerDiscipler: !person.isDiscipler,
      setupOpen: setupOpen,
    );
    if (choice == null || !mounted) return;
    final ok = await _controller.setUpMember(
      person.placement.placementId,
      choice,
    );
    // Show the person where they now are, ready for the next step
    // (pairing), rather than an emptied Needs setup list.
    if (ok && mounted && _filter == GroupFilter.needsSetup) {
      setState(
        () => _filter = choice == DGroupResponsibility.disciple
            ? GroupFilter.disciples
            : GroupFilter.disciplers,
      );
    }
  }

  Future<void> _remove(GroupPerson person) async {
    final dr = person.disciplerRow;
    final dd = person.discipleRow;
    final theirDisciples = dr == null ? 0 : detail.disciplesOf(dr).length;
    final paired = dd != null && detail.disciplerOf(dd) != null;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${person.fullName}?',
      message: [
        'They will leave ${detail.group.name}. Their history is kept.',
        if (theirDisciples > 0)
          '${MinistryFormat.count(theirDisciples, 'Disciple')} paired with '
              'them will be unpaired.',
        if (paired) 'Their own pairing with their Discipler ends.',
      ].join(' '),
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await _controller.removeFromGroup(person.placement.placementId);
  }

  Future<void> _appoint(DisciplerCandidate candidate) async {
    if (!await confirmAppointment(context, candidate) || !mounted) return;
    final ok = await _controller.appointDiscipler(candidate.churchMembershipId);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${candidate.fullName} is now a Discipler.')),
    );
  }

  Future<void> _pair(DGroupMember disciple) async {
    final selection = await showPairSheet(
      context,
      detail: detail,
      disciple: disciple,
    );
    if (selection == null || !mounted) return;
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
    await _controller.setDiscipler(
      disciple.dGroupMembershipId,
      selection.disciplerDGroupMembershipId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final structure = ref.watch(ministryStructureControllerProvider);
    final isCoordinator = ref.watch(isCoordinatorProvider);
    final myContext = ref.watch(myMinistryContextProvider).value;
    final isLeaderHere =
        myContext != null &&
        myContext.isLeader &&
        myContext.dGroupId == _groupId;
    final canManage = isCoordinator || isLeaderHere;
    final offline = ConnectionScope.isOffline(context);
    final setupOpen =
        ref.watch(initialSetupStatusProvider).value?.isOpen ?? false;
    // Members' progress, for the group's Leader and the Coordinator only.
    // Rows fall back to plain faces while it loads or if refused.
    final progress = canManage
        ? ref.watch(groupProgressProvider(_groupId)).value
        : null;
    // Eligible Disciples (derived by the database), for the same viewers.
    final candidates = canManage
        ? {
            for (final c
                in ref
                        .watch(groupDisciplerCandidatesProvider(_groupId))
                        .value ??
                    const <DisciplerCandidate>[])
              c.churchMembershipId: c,
          }
        : const <String, DisciplerCandidate>{};

    final leader = detail.leader;
    final people = detail.people;
    final counts = detail.filterCounts;
    final shown = people.where(_filter.includes).toList();
    final disciples = detail.disciples;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.group.description != null) ...[
          Text(detail.group.description!, style: context.supportingStyle),
          const SizedBox(height: AppSpacing.md),
        ],

        // The one primary action, placed first (UI_DESIGN_SYSTEM section 40).
        if (canManage) ...[
          AppButton(
            label: 'Add members',
            requiresConnection: true,
            icon: Icons.person_add_alt_outlined,
            onPressed: structure.isBusy ? null : _addMembers,
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
                  onTap: structure.isBusy ? null : _changeLeader,
                )
              : null,
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: PersonRow(
            name: leader?.fullName ?? 'No Leader',
            leading: leader == null
                ? null
                : MemberAvatar(
                    name: leader.fullName,
                    membershipId: leader.churchMembershipId,
                  ),
            detail: leader?.phone,
            pills: [
              if (leader != null) ...const [
                RoleBadge(label: 'Leader', tone: PillTone.ink),
                RoleBadge(label: 'Discipler', tone: PillTone.brand),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Members ---------------------------------------------------------
        SectionHeading('Members'),
        if (disciples.isNotEmpty) ...[
          PairingProgress(
            paired: disciples
                .where((d) => detail.disciplerOf(d) != null)
                .length,
            total: disciples.length,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _FilterChips(
          selected: _filter,
          counts: counts,
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (shown.isEmpty)
          EmptyState(
            illustration: _filter == GroupFilter.needsSetup
                ? Illustration.complete
                : Illustration.group,
            title: _filter == GroupFilter.needsSetup
                ? 'All set up'
                : 'Nobody here yet',
            message: _emptyLine(_filter, canManage: canManage),
          )
        else
          TileGroup(
            children: [
              for (final person in shown)
                _MemberRow(
                  person: person,
                  detail: detail,
                  progress: progress?[person.churchMembershipId],
                  candidate: candidates[person.churchMembershipId],
                  isCoordinator: isCoordinator,
                  canManage: canManage,
                  enabled: !structure.isBusy && !offline,
                  busy:
                      structure.isRunning(
                        'setup:${person.placement.placementId}',
                      ) ||
                      structure.isRunning(
                        'appoint:${person.churchMembershipId}',
                      ) ||
                      (person.discipleRow != null &&
                          structure.isRunning(
                            'pair:${person.discipleRow!.dGroupMembershipId}',
                          )),
                  onSetUp: () => _setUp(person, setupOpen: setupOpen),
                  onPair: person.discipleRow == null
                      ? null
                      : () => _pair(person.discipleRow!),
                  menu: [
                    if (isCoordinator &&
                        candidates[person.churchMembershipId] != null)
                      (
                        'Appoint as Discipler',
                        () => _appoint(candidates[person.churchMembershipId]!),
                      ),
                    if (person.isDiscipler &&
                        !person.isDisciple &&
                        !person.isLeader)
                      (
                        'Add as a Disciple too',
                        () => _controller.setUpMember(
                          person.placement.placementId,
                          DGroupResponsibility.disciple,
                        ),
                      ),
                    if (person.isDisciple && !person.isDiscipler && setupOpen)
                      (
                        'Recognize as Existing Discipler',
                        () => _controller.setUpMember(
                          person.placement.placementId,
                          DGroupResponsibility.discipler,
                        ),
                      ),
                    if (!person.isLeader)
                      ('Remove from group', () => _remove(person)),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  static String _emptyLine(GroupFilter f, {required bool canManage}) =>
      switch (f) {
        GroupFilter.all =>
          canManage
              ? 'No one else is in this group yet. Use Add members to bring '
                    'people in.'
              : 'No one else is in this group yet.',
        GroupFilter.disciples => 'No Disciples yet.',
        GroupFilter.disciplers => 'No Disciplers yet.',
        GroupFilter.needsSetup =>
          'Everyone in this group has a role. New members you add appear '
              'here until you set them up.',
      };
}

/// Local filters with their counts, as one fixed row of tabs that share
/// the width, so none wraps or is cut off. The active tab is marked by its
/// text and a thin lime outline only (user decision 2026-10-07).
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final GroupFilter selected;
  final Map<GroupFilter, int> counts;
  final ValueChanged<GroupFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = pillColors(context, PillTone.brand).$2;
    return Row(
      children: [
        for (final (i, f) in GroupFilter.values.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          // Width follows the label, so every tab keeps the same type size.
          Expanded(
            flex: f.label.length + 4,
            child: Semantics(
              button: true,
              selected: f == selected,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(
                      side: f == selected
                          ? BorderSide(color: p.brand, width: 1.2)
                          : BorderSide.none,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: f.label),
                          TextSpan(
                            text: ' ${counts[f] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: f == selected ? active : p.muted,
                        fontWeight: f == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One person in the group list. Kept to two lines of text: the name with
/// role pills, then the one fact that matters most for their role.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.detail,
    required this.progress,
    required this.candidate,
    required this.isCoordinator,
    required this.canManage,
    required this.enabled,
    required this.busy,
    required this.onSetUp,
    required this.onPair,
    required this.menu,
  });

  final GroupPerson person;
  final DGroupDetail detail;

  /// The person's progress as a Disciple, when the viewer may see it.
  final DiscipleProgressSummary? progress;

  /// Set when the person is eligible to be appointed (not yet appointed).
  final DisciplerCandidate? candidate;
  final bool isCoordinator;
  final bool canManage;
  final bool enabled;
  final bool busy;
  final VoidCallback onSetUp;
  final VoidCallback? onPair;
  final List<(String, VoidCallback)> menu;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final dd = person.discipleRow;
    final dr = person.disciplerRow;
    final discipler = dd == null ? null : detail.disciplerOf(dd);
    final theirDisciples = dr == null
        ? const <DGroupMember>[]
        : detail.disciplesOf(dr);

    // Who the person is, as small badges, and at most one state badge
    // (UI_DESIGN_SYSTEM section 39). Dates and explanations live on the
    // pages that act on them, so a row stays to three short lines.
    final badges = <Widget>[
      if (person.isLeader) const RoleBadge(label: 'Leader', tone: PillTone.ink),
      if (person.isDiscipler)
        const RoleBadge(label: 'Discipler', tone: PillTone.brand),
      if (person.isDisciple)
        const RoleBadge(label: 'Disciple', tone: PillTone.info),
      if (person.needsSetup)
        const RoleBadge(label: 'Needs setup', tone: PillTone.warning),
      if (candidate != null)
        const RoleBadge(label: 'Eligible', tone: PillTone.warning),
    ];

    // One fact line: where a Disciple is and with whom, how many Disciples
    // a Discipler has, or when a newcomer was added.
    final Widget? fact = person.needsSetup
        ? Text(
            'Added ${MinistryFormat.shortDate(person.placement.startedAt)}',
            style: context.captionStyle,
          )
        : dd != null
        ? Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (progress != null)
                ProgressFact(
                  progress!.currentLessonNumber == null
                      ? 'Every lesson completed'
                      : 'Lesson ${progress!.currentLessonNumber} of '
                            '${progress!.lessonsTotal}',
                ),
              Text(
                discipler != null
                    ? 'with ${discipler.fullName}'
                    : 'Not paired yet',
                style: context.captionStyle.copyWith(
                  color: discipler != null
                      ? p.muted
                      : pillColors(context, PillTone.warning).$2,
                ),
              ),
            ],
          )
        : dr != null
        ? Text(
            theirDisciples.isEmpty
                ? 'No Disciples yet'
                : theirDisciples.length == 1
                ? 'Disciples ${theirDisciples.single.fullName}'
                : '${theirDisciples.length} Disciples',
            style: context.captionStyle,
          )
        : null;

    // Compact icon actions, never wide pills; the tooltip names each one.
    final Widget? action;
    if (!canManage) {
      action = null;
    } else if (busy) {
      action = const Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (person.needsSetup) {
      action = _RowAction(
        icon: Icons.person_add_alt_1_rounded,
        tooltip: 'Set up',
        emphasised: true,
        onPressed: enabled ? onSetUp : null,
      );
    } else if (dd != null && discipler == null) {
      action = _RowAction(
        icon: Icons.link_rounded,
        tooltip: 'Pair',
        emphasised: true,
        onPressed: enabled ? onPair : null,
      );
    } else if (dd != null) {
      action = _RowAction(
        icon: Icons.swap_horiz_rounded,
        tooltip: 'Change Discipler',
        onPressed: enabled ? onPair : null,
      );
    } else {
      action = null;
    }

    return InkWell(
      onTap: dd == null
          ? null
          : () => context.push(
              Routes.discipleDetailFor(person.churchMembershipId),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            MemberAvatar(
              name: person.fullName,
              membershipId: person.churchMembershipId,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 4, runSpacing: 4, children: badges),
                  ],
                  if (fact != null) ...[const SizedBox(height: 4), fact],
                ],
              ),
            ),
            ?action,
            if (canManage && menu.isNotEmpty)
              PopupMenuButton<int>(
                tooltip: 'More actions',
                enabled: enabled,
                icon: Icon(Icons.more_horiz_rounded, color: p.muted),
                onSelected: (i) => menu[i].$2(),
                itemBuilder: (_) => [
                  for (var i = 0; i < menu.length; i++)
                    PopupMenuItem(value: i, child: Text(menu[i].$1)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A row action as a compact round icon button. The one that moves a person
/// forward (Set up, Pair) is lime-tinted; Change stays quiet.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasised = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pillColors(
      context,
      emphasised ? PillTone.brand : PillTone.neutral,
    );
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: emphasised ? bg : neutralFill(context),
        foregroundColor: emphasised ? fg : context.palette.textPrimary,
        minimumSize: const Size(40, 40),
      ),
    );
  }
}
