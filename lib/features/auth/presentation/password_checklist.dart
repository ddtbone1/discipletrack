import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/password_policy.dart';

/// The password rules, each ticked as the typed password meets it.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ok = pillColors(context, PillTone.brand).$2;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in passwordRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Semantics(
              label: '${r.label}: ${r.passes(password) ? 'done' : 'not yet'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(
                    r.passes(password)
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: r.passes(password) ? ok : p.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r.label,
                    style: text.bodySmall?.copyWith(
                      color: r.passes(password) ? p.textPrimary : p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
