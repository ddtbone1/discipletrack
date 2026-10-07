import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page_header.dart';

/// Home's greeting as the page's title: "Good morning," in grey and the
/// person's name in the text colour beside it (user, 2026-10-07: no slogan).
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({required this.firstName, this.now, super.key});

  final String firstName;

  /// For tests; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final at = now ?? DateTime.now();
    final style = AppTypography.display.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.15,
    );
    final greeting = '${greetingFor(at)}, ';
    return Semantics(
      header: true,
      label: '$greeting$firstName',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: greeting,
              style: style.copyWith(color: p.muted),
            ),
            TextSpan(
              text: firstName,
              style: style.copyWith(color: p.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
