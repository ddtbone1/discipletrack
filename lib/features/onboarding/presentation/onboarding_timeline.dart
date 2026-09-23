import 'package:flutter/material.dart';

import '../../../core/widgets/step_list.dart';
import '../domain/onboarding_steps.dart';

/// The onboarding timeline: [onboardingSteps] rendered as a [StepList], with
/// an optional action widget under any step.
///
/// UI_DESIGN_SYSTEM sections 32 and 34: the timeline is the informational
/// foundation of onboarding and sits directly on the page background.
class OnboardingTimeline extends StatelessWidget {
  const OnboardingTimeline({required this.steps, this.detailFor, super.key});

  final List<OnboardingStep> steps;

  /// Returns the widget to show under a step, or null for none.
  final Widget? Function(OnboardingStep step)? detailFor;

  @override
  Widget build(BuildContext context) {
    return StepList(
      steps: [
        for (final step in steps)
          StepItem(
            title: step.title,
            subtitle: step.subtitle,
            state: step.state,
            detail: detailFor?.call(step),
          ),
      ],
    );
  }
}
