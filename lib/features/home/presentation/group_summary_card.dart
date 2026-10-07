import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_pill.dart';
import '../../ministry/domain/d_group_member.dart';
import '../../ministry/domain/ministry_context.dart';
import '../../ministry/presentation/ministry_ui.dart';

/// The person's D Group on Home, as one white card with a soft shadow
/// (user, 2026-10-07): the group's name and the person's place in it, a
/// row of small labelled facts, and the group's make-up as one bar.
/// Opens the roster.
class GroupSummaryCard extends StatelessWidget {
  const GroupSummaryCard({required this.ministry, super.key});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = ministry;
    final members = c.groupSize;
    final leader = c.leader;
    final discipler = c.myDiscipler;
    final disciples = c.myDisciples;

    // Every Leader is a Discipler (ADR-020), so "the Leader" says both.
    final roles = [
      for (final r in DGroupResponsibility.values)
        if (c.myResponsibilities.contains(r) &&
            !(c.isLeader && r == DGroupResponsibility.discipler))
          r,
    ];

    // The group's make-up: people per responsibility, and those placed
    // without one yet (ADR-018).
    Set<String> holding(DGroupResponsibility r) => {
      for (final e in c.roster)
        if (e.responsibility == r) e.churchMembershipId,
    };
    final disciplerCount = holding(DGroupResponsibility.discipler).length;
    final discipleCount = holding(DGroupResponsibility.disciple).length;
    final placed = {for (final e in c.roster) e.churchMembershipId}.length;
    final setup = (members - placed).clamp(0, members);

    // Up to three facts, the ones that matter to this person.
    final facts = <({String label, String value, bool warn})>[
      (label: 'Members', value: '$members', warn: false),
      if (leader != null && !c.isLeader)
        (label: 'Leader', value: _first(leader.fullName), warn: false),
      if (c.isDisciple)
        discipler == null
            ? (label: 'Discipler', value: 'Not paired', warn: true)
            : (
                label: 'Discipler',
                value: _first(discipler.fullName),
                warn: false,
              ),
      if (c.isDiscipler)
        (label: 'Disciples', value: '${disciples.length}', warn: false),
    ].take(3).toList();

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
                    c.dGroupName,
                    style: text.titleLarge?.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Each role in its badge colour from My D Group.
                  Text.rich(
                    TextSpan(
                      style: text.bodySmall?.copyWith(color: p.muted),
                      children: roles.isEmpty
                          ? const [
                              TextSpan(text: "You're waiting for your role"),
                            ]
                          : [
                              const TextSpan(text: "You're "),
                              for (final (i, r) in roles.indexed) ...[
                                if (i > 0) const TextSpan(text: ' and '),
                                TextSpan(
                                  text: r == DGroupResponsibility.leader
                                      ? 'the '
                                      : 'a ',
                                ),
                                TextSpan(
                                  text: r.label,
                                  style: TextStyle(
                                    color: pillColors(context, roleTone(r)).$2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark ? Colors.white.withValues(alpha: 0.18) : p.border,
                ),
              ),
              child: Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (final f in facts)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.label,
                      style: text.labelSmall?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: f.warn
                            ? pillColors(context, PillTone.warning).$2
                            : p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (members > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _MakeUpBar(
            disciplers: disciplerCount,
            disciples: discipleCount,
            setup: setup,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$disciplerCount Disciplers  ·  $discipleCount Disciples',
                  style: text.labelSmall?.copyWith(color: p.muted),
                ),
              ),
              if (setup > 0)
                Text(
                  setup == 1 ? '1 needs setup' : '$setup need setup',
                  style: text.labelSmall?.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        // In dark mode a shadow barely shows on black, so the card lifts
        // by light instead: a slightly brighter surface, lit from the top,
        // and a hairline edge.
        gradient: dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(p.surface, Colors.white, 0.08)!,
                  Color.lerp(p.surface, Colors.white, 0.03)!,
                ],
              )
            : null,
        border: dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.09))
            : null,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.6 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.myGroup),
          child: Padding(padding: const EdgeInsets.all(22), child: body),
        ),
      ),
    );
  }

  static String _first(String fullName) => fullName.split(' ').first;
}

/// The group's make-up as one rounded bar: Disciplers in the deep green,
/// Disciples in lime, people waiting for setup hatched.
class _MakeUpBar extends StatelessWidget {
  const _MakeUpBar({
    required this.disciplers,
    required this.disciples,
    required this.setup,
  });

  final int disciplers;
  final int disciples;
  final int setup;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = disciplers + disciples + setup;
    if (total == 0) return const SizedBox.shrink();
    return Semantics(
      label:
          '$disciplers Disciplers, $disciples Disciples'
          '${setup > 0 ? ', $setup waiting for setup' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (disciplers > 0)
              Expanded(
                flex: disciplers,
                child: _Segment(color: _deepGreen(context)),
              ),
            if (disciplers > 0 && (disciples > 0 || setup > 0))
              const SizedBox(width: 3),
            if (disciples > 0)
              Expanded(
                flex: disciples,
                child: _Segment(color: p.brand),
              ),
            if (disciples > 0 && setup > 0) const SizedBox(width: 3),
            if (setup > 0)
              Expanded(
                flex: setup,
                child: const _Segment(color: Colors.transparent, hatched: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.color, this.hatched = false});

  final Color color;
  final bool hatched;

  @override
  Widget build(BuildContext context) {
    // Stripes over the segment: darker on the light card, brighter on the
    // dark one, so the part still to set up reads in either mode.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stripe = dark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: CustomPaint(
        foregroundPainter: hatched ? _Hatch(stripe) : null,
        child: ColoredBox(color: color),
      ),
    );
  }
}

/// Diagonal stripes, as the reference bar marks what is still to come.
class _Hatch extends CustomPainter {
  _Hatch(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Hatch old) => old.color != color;
}

/// The Disciplers' colour: the brand's deep green in light mode; in dark
/// mode a soft green, so the bar keeps two tones beside the lime.
Color _deepGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(context.palette.brand, Colors.black, 0.5)!
    : pillColors(context, PillTone.brand).$2;
