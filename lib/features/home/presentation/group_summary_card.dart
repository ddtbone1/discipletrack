import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../../ministry/domain/d_group_member.dart';
import '../../ministry/domain/ministry_context.dart';

/// The pastel green fill on the Home group card (user request of
/// 2026-10-05). Set to false for the plain white card.
const _useGreen = true;

/// Colours for the card: a plain pastel green with black content in light
/// mode, a deep green with white content in dark mode, so the content is
/// always clearly visible.
typedef _Ink = ({Color card, Color text, Color muted, Color button});

/// The person's D Group on Home, kept minimal: the group's name, the
/// person's own responsibility, the people in it at a glance, and who
/// matters to them there. Opens the group: the detail page for its Leader,
/// the roster for everyone else.
class GroupSummaryCard extends StatelessWidget {
  const GroupSummaryCard({required this.ministry, super.key});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final _Ink ink = !_useGreen
        ? (
            card: p.surface,
            text: p.textPrimary,
            muted: p.muted,
            button: p.textPrimary,
          )
        : dark
        ? (
            card: const Color(0xFF1E2C11),
            text: Colors.white,
            muted: Colors.white.withValues(alpha: 0.7),
            button: Colors.white,
          )
        : (
            card: const Color(0xFFE6FBC8),
            text: Colors.black,
            muted: Colors.black.withValues(alpha: 0.6),
            button: Colors.black,
          );
    final c = ministry;
    final mates = c.groupMates;
    final members = {for (final e in c.roster) e.churchMembershipId}.length;
    final leader = c.leader;
    final discipler = c.myDiscipler;
    final disciples = c.myDisciples;
    final roles = [
      for (final r in DGroupResponsibility.values)
        if (c.myResponsibilities.contains(r)) r.label,
    ];

    void open() => context.push(
      c.isLeader ? Routes.dGroupDetailFor(c.dGroupId) : Routes.myGroup,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My D Group',
                    style: text.bodySmall?.copyWith(
                      color: ink.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.dGroupName,
                    style: text.headlineSmall?.copyWith(
                      color: ink.text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You're ${_withArticle(roles)}",
                    style: text.bodyMedium?.copyWith(color: ink.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ink.button,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_outward_rounded,
                size: 20,
                color: ink.card,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _AvatarStack(
              names: [for (final m in mates) m.fullName],
              ring: ink.card,
              counter: ink.button,
              counterText: ink.card,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              members == 1 ? '1 member' : '$members members',
              style: text.bodyMedium?.copyWith(
                color: ink.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (leader != null ||
            c.isDisciple ||
            (c.isDiscipler && !c.isLeader)) ...[
          const SizedBox(height: AppSpacing.md),
          if (leader != null)
            _Person(name: leader.fullName, role: 'Your Leader', ink: ink),
          if (c.isDisciple)
            discipler == null
                ? _Person(
                    name: 'Not paired with a Discipler yet',
                    ink: ink,
                    icon: Icons.link_off_rounded,
                    trailing: const AppPill(
                      tone: PillTone.warning,
                      label: 'Not paired',
                    ),
                  )
                : _Person(
                    name: discipler.fullName,
                    role: 'Your Discipler',
                    ink: ink,
                  ),
          if (c.isDiscipler)
            _Person(
              name: disciples.isEmpty
                  ? 'No Disciples paired with you yet'
                  : disciples.length == 1
                  ? '1 Disciple paired with you'
                  : '${disciples.length} Disciples paired with you',
              icon: Icons.people_alt_outlined,
              ink: ink,
            ),
        ],
      ],
    );

    if (!_useGreen) return AppCard(onTap: open, child: body);

    return Material(
      color: ink.card,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(padding: const EdgeInsets.all(22), child: body),
      ),
    );
  }

  /// "a Discipler", "the Leader and a Discipler".
  static String _withArticle(List<String> roles) =>
      [for (final r in roles) r == 'Leader' ? 'the Leader' : 'a $r']
          .join(' and ');
}

/// Up to five overlapping avatars in their name colours, then "+n".
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.names,
    required this.ring,
    required this.counter,
    required this.counterText,
  });

  final List<String> names;
  final Color ring;
  final Color counter;
  final Color counterText;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    const radius = 17.0;
    const step = 24.0;
    final shown = names.take(5).toList();
    final extra = names.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return ExcludeSemantics(
      child: SizedBox(
        width: step * (count - 1) + radius * 2 + 4,
        height: radius * 2 + 4,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: step * i,
                child: CircleAvatar(
                  radius: radius + 2,
                  backgroundColor: ring,
                  child: InitialsAvatar(name: shown[i], radius: radius),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: step * shown.length,
                child: CircleAvatar(
                  radius: radius + 2,
                  backgroundColor: ring,
                  child: CircleAvatar(
                    radius: radius,
                    backgroundColor: counter,
                    child: Text(
                      '+$extra',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: counterText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One person who matters to the viewer: avatar, name, and their relation
/// in plain muted text rather than a pill.
class _Person extends StatelessWidget {
  const _Person({
    required this.name,
    required this.ink,
    this.role,
    this.icon,
    this.trailing,
  });

  final String name;
  final _Ink ink;
  final String? role;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon == null)
            InitialsAvatar(name: name, radius: 16)
          else
            SizedBox(width: 32, child: Icon(icon, size: 20, color: ink.text)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.bodyMedium?.copyWith(
                    color: ink.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (role != null)
                  Text(
                    role!,
                    style: text.bodySmall?.copyWith(color: ink.muted),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
