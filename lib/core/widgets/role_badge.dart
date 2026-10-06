import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'app_pill.dart';

/// A small badge for who someone is (Leader, Discipler, Disciple) or a
/// short state beside a name (Needs setup, Eligible): a soft tinted fill,
/// no border, caption-sized (user decision 2026-10-06).
///
/// Badges and coloured text have different jobs (UI_DESIGN_SYSTEM section
/// 39): a badge labels a person; coloured text states a progress fact
/// such as "Lesson 6 of 10". The colour only helps; the word says it.
class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.label, required this.tone, super.key});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pillColors(context, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: context.captionStyle.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

/// A progress fact as coloured text ("Lesson 6 of 10"), never a pill.
class ProgressFact extends StatelessWidget {
  const ProgressFact(this.text, {this.tone = PillTone.brand, super.key});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (_, fg) = pillColors(context, tone);
    return Text(
      text,
      style: context.captionStyle.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
