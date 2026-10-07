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
import '../../../core/widgets/charts.dart';
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
import '../../profile/presentation/member_avatar.dart';
import 'ministry_ui.dart';
import 'needs_setup_notice.dart';
import 'no_disciples_guide.dart';

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
PillTone _toneOf(DGroupResponsibility r) => roleTone(r);

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
    // Everyone else, clustered by role.
    List<RosterEntry> othersIn(DGroupResponsibility r) {
      final seen = <String>{};
      return [
        for (final m in c.roster)
          if (m.responsibility == r &&
              !m.isMe &&
              !shown.contains(m.churchMembershipId) &&
              seen.add(m.churchMembershipId))
            m,
      ];
    }

    final otherDisciplers = othersIn(DGroupResponsibility.discipler);
    final otherDisciples = othersIn(DGroupResponsibility.disciple);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. The group at a glance: who it is made of.
        _GroupOverview(ministry: c),
        if (c.isLeader) ...[
          const SizedBox(height: AppSpacing.sm),
          _LeaderControls(ministry: c),
        ],

        // 2. The people who walk with this person.
        if (leader != null || c.isDisciple) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeading('Walking with you'),
          TileGroup(
            children: [
              if (leader != null)
                _PersonTile(
                  name: leader.fullName,
                  membershipId: leader.churchMembershipId,
                  role: DGroupResponsibility.leader,
                  phone: leader.phone,
                ),
              if (c.isDisciple)
                discipler == null
                    ? const _PersonTile(
                        name: 'Not paired with a Discipler yet',
                        icon: Icons.link_off_rounded,
                        iconTone: PillTone.warning,
                        detail: 'Your Leader pairs you with one.',
                      )
                    : _PersonTile(
                        name: discipler.fullName,
                        membershipId: discipler.churchMembershipId,
                        role: DGroupResponsibility.discipler,
                        phone: discipler.phone,
                      ),
            ],
          ),
        ],

        // 3. The people this person disciples, with where they are.
        if (c.isDiscipler) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeading(
            'Your Disciples',
            trailing: disciples.isEmpty
                ? null
                : AppTextLink(
                    label: 'See progress',
                    onTap: () => context.go(Routes.journeyDisciples),
                  ),
          ),
          if (disciples.isEmpty)
            const NoDisciplesGuide()
          else ...[
            TileGroup(
              children: [
                for (final d in disciples)
                  _PersonTile(
                    name: d.fullName,
                    membershipId: d.churchMembershipId,
                    phone: d.phone,
                    pills: _progressPills(
                      context,
                      progress[d.churchMembershipId],
                    ),
                    progress: switch (progress[d.churchMembershipId]) {
                      final s? when s.lessonsTotal > 0 =>
                        s.lessonsCompleted / s.lessonsTotal,
                      _ => 0,
                    },
                    onTap: () => context.push(
                      Routes.discipleDetailFor(d.churchMembershipId),
                    ),
                  ),
              ],
            ),
          ],
        ],

        // 4. The rest of the group, by role.
        for (final (title, people) in [
          ('Disciplers', otherDisciplers),
          ('Disciples', otherDisciples),
        ])
          if (people.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeading('$title  ·  ${people.length}'),
            TileGroup(
              children: [
                for (final m in people)
                  _PersonTile(
                    name: m.fullName,
                    membershipId: m.churchMembershipId,
                  ),
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

/// The group at a glance: its name, the person's own place in it, and a
/// ring of who it is made of, with the counts beside it.
class _GroupOverview extends StatelessWidget {
  const _GroupOverview({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    int count(DGroupResponsibility r) => {
      for (final e in ministry.roster)
        if (e.responsibility == r) e.churchMembershipId,
    }.length;
    final placed = {for (final e in ministry.roster) e.churchMembershipId};
    final setup = (ministry.groupSize - placed.length).clamp(0, 999);
    final mine = [
      for (final r in DGroupResponsibility.values)
        if (ministry.myResponsibilities.contains(r) &&
            !(ministry.isLeader && r == DGroupResponsibility.discipler))
          r,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ministry.dGroupName,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: "You're "),
                for (final (i, r) in mine.indexed) ...[
                  if (i > 0) const TextSpan(text: ' and '),
                  TextSpan(
                    text: r == DGroupResponsibility.leader ? 'the ' : 'a ',
                  ),
                  TextSpan(
                    text: r.label,
                    style: TextStyle(
                      color: pillColors(context, _toneOf(r)).$2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          DonutChart(
            centerValue: '${ministry.groupSize}',
            centerLabel: 'members',
            slices: [
              (
                value: count(DGroupResponsibility.leader),
                color: p.textPrimary,
                label: 'Leader',
              ),
              (
                value: count(DGroupResponsibility.discipler),
                color: pillColors(context, PillTone.brand).$2,
                label: 'Disciplers',
              ),
              (
                value: count(DGroupResponsibility.disciple),
                color: p.brand,
                label: 'Disciples',
              ),
              if (setup > 0)
                (
                  value: setup,
                  color: pillColors(context, PillTone.warning).$2,
                  label: 'Needs setup',
                ),
            ],
          ),
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
    this.progress,
    this.membershipId,
    this.icon,
    this.iconTone = PillTone.neutral,
  });

  final String name;
  final DGroupResponsibility? role;
  final String? phone;
  final String? detail;
  final List<Widget> pills;
  final VoidCallback? onTap;

  /// Lessons completed out of the curriculum, for a Disciple's ring.
  final double? progress;

  /// The person's church membership id, for their avatar.
  final String? membershipId;

  /// For an empty row: an icon in place of a person's initials.
  final IconData? icon;
  final PillTone iconTone;

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
        children: [
          if (icon == null)
            MemberAvatar(
              name: name,
              membershipId: membershipId,
              progress: progress,
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: pillColors(context, iconTone).$1,
              child: Icon(
                icon,
                size: 20,
                color: pillColors(context, iconTone).$2,
              ),
            ),
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
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.muted),
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
