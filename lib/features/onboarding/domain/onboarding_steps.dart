import 'package:flutter/foundation.dart';

import '../../../core/widgets/step_list.dart';

/// Where the person is in the onboarding journey. Derived from the session
/// state by each screen; there is no separate stored onboarding state.
enum OnboardingStage {
  /// Verified account, no membership yet.
  join,

  /// PENDING membership.
  pending,

  /// ACTIVE membership, first-entry welcome not yet completed.
  ready,
}

/// One row of the onboarding timeline.
@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.state,
    this.subtitle,
  });

  final String title;
  final StepProgress state;
  final String? subtitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingStep &&
          other.title == title &&
          other.state == state &&
          other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, state, subtitle);
}

/// The five onboarding steps with their state for [stage].
///
/// Reaching any of these screens already implies a verified account and a
/// session, so the first two steps are always done. [churchName] labels the
/// church step once a request exists.
List<OnboardingStep> onboardingSteps(
  OnboardingStage stage, {
  String? churchName,
}) {
  StepProgress at(OnboardingStage current) => stage.index > current.index
      ? StepProgress.done
      : stage.index == current.index
      ? StepProgress.current
      : StepProgress.upcoming;

  return [
    const OnboardingStep(title: 'Account created', state: StepProgress.done),
    const OnboardingStep(title: 'Email verified', state: StepProgress.done),
    OnboardingStep(
      title: 'Join church',
      state: at(OnboardingStage.join),
      subtitle: stage == OnboardingStage.join
          ? 'Enter the code your church gave you.'
          : churchName,
    ),
    OnboardingStep(
      title: 'Waiting for approval',
      state: at(OnboardingStage.pending),
      subtitle: switch (stage) {
        OnboardingStage.join =>
          'Your church reviews your request before you get access.',
        OnboardingStage.pending =>
          'Your church is reviewing your request. Nothing else is needed '
              'from you.',
        OnboardingStage.ready => 'Approved',
      },
    ),
    OnboardingStep(
      title: 'Ready to begin',
      state: at(OnboardingStage.ready),
      subtitle: stage == OnboardingStage.ready
          ? 'Your church workspace is open.'
          : 'Your D Group and discipleship journey appear here.',
    ),
  ];
}
