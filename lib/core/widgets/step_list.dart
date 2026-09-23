import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StepProgress { done, current, upcoming }

/// One step in a [StepList].
class StepItem {
  const StepItem({
    required this.title,
    required this.state,
    this.subtitle,
    this.detail,
  });

  final String title;
  final StepProgress state;
  final String? subtitle;

  /// Optional content shown under the subtitle, typically on the current step.
  final Widget? detail;
}

/// A vertical, sequential progress timeline (UI_DESIGN_SYSTEM section 32).
///
/// Sits on the page background rather than inside a card (section 34). Each
/// step is announced with its position and state, so progress does not depend
/// on the indicator colours alone.
class StepList extends StatelessWidget {
  const StepList({required this.steps, super.key});

  final List<StepItem> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            index: i,
            count: steps.length,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.count,
    required this.isLast,
  });

  final StepItem step;
  final int index;
  final int count;
  final bool isLast;

  static const _indicator = 26.0;

  String get _stateLabel => switch (step.state) {
    StepProgress.done => 'completed',
    StepProgress.current => 'current step',
    StepProgress.upcoming => 'not started',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final upcoming = step.state == StepProgress.upcoming;

    // IntrinsicHeight is scoped to one short row so the connector line can
    // stretch to the row's height. Never wrap the whole list or page in it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _indicator,
            child: Column(
              children: [
                _Indicator(state: step.state, number: index + 1),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: step.state == StepProgress.done
                            ? p.textPrimary
                            : p.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 3,
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label:
                        'Step ${index + 1} of $count, ${step.title}, '
                        '$_stateLabel',
                    excludeSemantics: true,
                    child: Text(
                      step.title,
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 15,
                        color: upcoming ? p.muted : p.textPrimary,
                      ),
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(step.subtitle!, style: context.supportingStyle),
                  ],
                  if (step.detail != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    step.detail!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.state, required this.number});

  final StepProgress state;
  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const size = _StepRow._indicator;

    return switch (state) {
      StepProgress.done => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: p.textPrimary, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 16, color: p.background),
      ),
      StepProgress.current => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.mint,
          shape: BoxShape.circle,
          border: Border.all(color: p.textPrimary, width: 2),
        ),
        child: Text(
          '$number',
          style: AppTypography.caption.copyWith(
            color: p.onMint,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      StepProgress.upcoming => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.border, width: 2),
        ),
        child: Text(
          '$number',
          style: AppTypography.caption.copyWith(
            color: p.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    };
  }
}
