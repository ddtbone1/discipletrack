import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page_header.dart';

/// A short ministry line for Home, split so its key words can be
/// highlighted.
typedef Slogan = ({String lead, String highlight, String tail});

/// The lines Home rotates through, one per day.
const slogans = <Slogan>[
  (lead: 'Grow ', highlight: 'together', tail: ', one lesson at a time.'),
  (lead: 'Make disciples who ', highlight: 'make disciples', tail: '.'),
  (lead: 'Small steps, ', highlight: 'faithfully', tail: ' taken.'),
  (lead: 'Walk ', highlight: 'with someone', tail: ' this week.'),
  (lead: 'Every meeting is a ', highlight: 'step forward', tail: '.'),
];

/// The slogan for [day]: the same all day, a different one tomorrow.
Slogan sloganFor(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return slogans[dayOfYear % slogans.length];
}

/// Home's greeting: "Good morning, James" as a small line, under it the
/// day's slogan as the page's title, with its key words highlighted in the
/// brand lime.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.firstName, this.now, super.key});

  final String firstName;

  /// For tests; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final at = now ?? DateTime.now();
    final slogan = sloganFor(at);
    final title = AppTypography.display.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.15,
      color: p.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingFor(at)}, $firstName',
          style: AppTypography.body.copyWith(
            color: p.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          label: '${slogan.lead}${slogan.highlight}${slogan.tail}',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              style: title,
              children: [
                TextSpan(text: slogan.lead),
                TextSpan(
                  text: slogan.highlight,
                  style: title.copyWith(
                    background: Paint()
                      ..color = p.brand.withValues(alpha: 0.55)
                      ..style = PaintingStyle.fill,
                  ),
                ),
                TextSpan(text: slogan.tail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
