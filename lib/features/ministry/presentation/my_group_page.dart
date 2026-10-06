import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
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
import '../application/ministry_providers.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_member.dart';
import '../domain/ministry_context.dart';
import 'ministry_ui.dart';
import 'needs_setup_notice.dart';

/// The roster for everyone in a group: their group at a glance, their
/// Leader, their own Discipler, a Discipler's own Disciples with where each
/// one is, and everyone else in the group by role. Every Leader is also a
/// Discipler (ADR-020) and uses this same page, with one added control to
/// manage the group's members.
///
/// Phone numbers appear only where `get_my_d_group_roster()` returned them
/// (Plan decision 8): the person's own Leader and own Discipler, and a
/// Discipler's assigned Disciples.
class MyGroupPage extends ConsumerWidget {
  const MyGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(myMinistryContextProvider);

    return AppScaffold(
      title: 'My D Group',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          ctx.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => SizedBox(
              height: 320,
              child: ErrorState.load(
                subject: 'your D Group',
                error: e,
                onRetry: () => ref.invalidate(myMinistryContextProvider),
              ),
            ),
            data: (c) => c == null
                ? const EmptyState(
                    illustration: Illustration.group,
                    message:
                        'You are not in a D Group yet. A D Group Leader adds '
                        'members to their group; once you are added, it shows '
                        'here.',
                  )
                : c.needsSetup
                ? NeedsSetupNotice(ministry: c)
                : _Roster(ministry: c),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Role colours, used the same way on every D Group page. Avatars use a
/// pastel chosen from the name; the role is coloured text (section 39).
PillTone _toneOf(DGroupResponsibility r) => switch (r) {
  DGroupResponsibility.leader => PillTone.ink,
  DGroupResponsibility.discipler => PillTone.brand,
  DGroupResponsibility.disciple => PillTone.info,
};

class _Roster extends ConsumerWidget {
  const _Roster({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ministry;
    final leader = c.leader;
    final discipler = c.myDiscipler;
    final disciples = c.myDisciples;
    final progress = {
      for (final d in ref.watch(myDisciplesProvider).value ?? const [])
        d.membershipId: d,
    };
    final shown = {
      ?leader?.churchMembershipId,
      ?discipler?.churchMembershipId,
      for (final d in disciples) d.churchMembershipId,
    };
    final others = [
      for (final m in c.groupMates)
        if (!shown.contains(m.churchMembershipId)) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(ministry: c),
        if (c.isLeader) ...[
          const SizedBox(height: AppSpacing.sm),
          _LeaderControls(ministry: c),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (leader != null) ...[
          const SectionHeading('Your Leader'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _PersonTile(
              name: leader.fullName,
              role: DGroupResponsibility.leader,
              phone: leader.phone,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (c.isDisciple) ...[
          const SectionHeading('Your Discipler'),
          AppCard(
            padding: EdgeInsets.zero,
            child: discipler == null
                ? const _PersonTile(
                    name: 'Not paired yet',
                    detail:
                        'Your Leader or the Coordinator will pair you with a '
                        'Discipler.',
                    pills: [
                      AppPill(
                        tone: PillTone.warning,
                        icon: Icons.link_off_rounded,
                        label: 'Not paired',
                      ),
                    ],
                  )
                : _PersonTile(
                    name: discipler.fullName,
                    role: DGroupResponsibility.discipler,
                    phone: discipler.phone,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (c.isDiscipler) ...[
          SectionHeading(
            'Your Disciples',
            trailing: disciples.isEmpty
                ? null
                : AppTextLink(
                    label: 'See progress',
                    onTap: () => context.go(Routes.journeyDisciples),
                  ),
          ),
          TileGroup(
            children: [
              if (disciples.isEmpty)
                const _PersonTile(
                  name: 'No Disciples paired with you yet',
                  detail:
                      'Your Leader or the Coordinator pairs Disciples with '
                      'you.',
                ),
              for (final d in disciples)
                _PersonTile(
                  name: d.fullName,
                  phone: d.phone,
                  pills: _progressPills(
                    context,
                    progress[d.churchMembershipId],
                  ),
                  onTap: () => context.push(
                    Routes.discipleDetailFor(d.churchMembershipId),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (others.isNotEmpty) ...[
          const SectionHeading('In your group'),
          TileGroup(
            children: [
              for (final m in others)
                _PersonTile(name: m.fullName, role: m.responsibility),
            ],
          ),
        ],
      ],
    );
  }

  /// Where a Disciple is: their lesson and their last recorded meeting.
  static List<Widget> _progressPills(
    BuildContext context,
    DiscipleProgressSummary? d,
  ) {
    if (d == null) return const [];
    // One line, one size: the lesson in colour, then the last meeting.
    final base = context.captionStyle;
    return [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: d.currentLessonNumber == null
                  ? 'Every lesson completed'
                  : 'Lesson ${d.currentLessonNumber} of ${d.lessonsTotal}',
              style: base.copyWith(
                color: pillColors(context, PillTone.brand).$2,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: '  ·  ${d.lastMeetingLine}', style: base),
          ],
        ),
      ),
    ];
  }
}

/// The group at a glance: its name, the person's own responsibilities as
/// pills, and how many people hold each role.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    int count(DGroupResponsibility r) => {
      for (final e in ministry.roster)
        if (e.responsibility == r) e.churchMembershipId,
    }.length;
    final mine = [
      for (final r in DGroupResponsibility.values)
        if (ministry.myResponsibilities.contains(r)) r,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: neutralFill(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.groups_2_rounded, color: p.textPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ministry.dGroupName,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        for (final r in mine)
                          RoleBadge(
                            label: 'You · ${r.label}',
                            tone: _toneOf(r),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg * 1.5),
          Row(
            children: [
              for (final r in DGroupResponsibility.values)
                Expanded(
                  child: _RoleCount(
                    count: count(r),
                    label: switch (r) {
                      DGroupResponsibility.leader => 'Leader',
                      DGroupResponsibility.discipler =>
                        count(r) == 1 ? 'Discipler' : 'Disciplers',
                      DGroupResponsibility.disciple =>
                        count(r) == 1 ? 'Disciple' : 'Disciples',
                    },
                    tone: _toneOf(r),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCount extends StatelessWidget {
  const _RoleCount({
    required this.count,
    required this.label,
    required this.tone,
  });

  final int count;
  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (_, fg) = pillColors(context, tone);
    return MergeSemantics(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTypography.metricSmall.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ],
          ),
          Text(label, style: context.captionStyle),
        ],
      ),
    );
  }
}

/// A person in the roster: avatar, name, a role pill, an optional phone
/// line and any extra pills.
class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.name,
    this.role,
    this.phone,
    this.detail,
    this.pills = const [],
    this.onTap,
  });

  final String name;
  final DGroupResponsibility? role;
  final String? phone;
  final String? detail;
  final List<Widget> pills;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: name),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: 8),
                      RoleBadge(label: role!.label, tone: _toneOf(role!)),
                    ],
                  ],
                ),
                if (phone != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.call_outlined, size: 14, color: p.muted),
                      const SizedBox(width: 4),
                      SelectableText(
                        phone!,
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: pills,
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right_rounded, color: p.muted),
            ),
        ],
      ),
    );
    return onTap == null ? tile : InkWell(onTap: onTap, child: tile);
  }
}

/// The Leader's way into managing the group: adding members, setting up
/// roles and pairing. Says how many people wait for setup, so pending work
/// shows without leaving the roster.
class _LeaderControls extends ConsumerWidget {
  const _LeaderControls({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref
        .watch(dGroupDetailProvider(ministry.dGroupId))
        .value
        ?.filterCounts[GroupFilter.needsSetup];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The roster's one primary for a Leader: lime, like the app's other
        // main actions.
        AppButton(
          label: 'Manage members',
          icon: Icons.manage_accounts_outlined,
          onPressed: () =>
              context.push(Routes.dGroupDetailFor(ministry.dGroupId)),
        ),
        if (waiting != null && waiting > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            waiting == 1
                ? '1 person needs their role set up.'
                : '$waiting people need their role set up.',
            textAlign: TextAlign.center,
            style: context.supportingStyle,
          ),
        ],
      ],
    );
  }
}
