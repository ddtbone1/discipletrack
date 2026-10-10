import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Where a multi-page task stands, at the top of each of its pages
/// (UI_DESIGN_SYSTEM section 60, Stepper): one segment per step, filled up to
/// the current one, and "Step 2 of 3 · Coordinator" beneath, so the position
/// never depends on colour alone. The same segmented bar as a D Group's
/// progress, in the brand colour for the steps behind and the current one.
class StepIndicator extends StatelessWidget {
  const StepIndicator({required this.steps, required this.current, super.key});

  /// The step names, in order.
  final List<String> steps;

  /// The current step, from 0.
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= current ? p.brand : p.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Step ${current + 1} of ${steps.length}'),
                TextSpan(
                  text: '  ·  ${steps[current]}',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: context.captionStyle,
          ),
        ],
      ),
    );
  }
}
