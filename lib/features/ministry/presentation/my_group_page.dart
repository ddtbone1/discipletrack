import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../discipleship/domain/disciple_progress_summary.dart';
import '../application/ministry_providers.dart';
import '../domain/d_group_member.dart';
import '../domain/ministry_context.dart';
import 'ministry_ui.dart';

/// The roster for a Discipler or Disciple: their group at a glance, their
/// Leader, their own Discipler, a Discipler's own Disciples with where each
/// one is, and everyone else in the group by role.
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
                    message:
                        'You are not in a D Group yet. When a Leader invites '
                        'you, the invitation appears on your Home screen.',
                  )
                : _Roster(ministry: c),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Role colours, used the same way on every D Group page: the Leader in
/// violet, Disciplers in teal, Disciples in blue. Avatars use a pastel
/// chosen from the name; the role is carried by the pill.
PillTone _toneOf(DGroupResponsibility r) => switch (r) {
  DGroupResponsibility.leader => PillTone.ink,
  DGroupResponsibility.discipler => PillTone.brand,
  DGroupResponsibility.disciple => PillTone.info,
};

IconData _iconOf(DGroupResponsibility r) => switch (r) {
  DGroupResponsibility.leader => Icons.star_rounded,
  DGroupResponsibility.discipler => Icons.school_outlined,
  DGroupResponsibility.disciple => Icons.person_outline_rounded,
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
    return [
      AppPill(
        icon: Icons.menu_book_outlined,
        label: d.currentLessonNumber == null
            ? 'Every lesson completed'
            : 'Lesson ${d.currentLessonNumber} of ${d.lessonsTotal}',
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(d.lastMeetingLine, style: context.supportingStyle),
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
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final r in mine)
                          AppPill(
                            tone: PillTone.brand,
                            icon: _iconOf(r),
                            label: 'You · ${r.label}',
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
                      const SizedBox(width: 6),
                      AppPill(
                        tone: role == DGroupResponsibility.leader
                            ? PillTone.brand
                            : PillTone.outline,
                        icon: _iconOf(role!),
                        label: role!.label,
                      ),
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
                  Wrap(spacing: 6, runSpacing: 6, children: pills),
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
