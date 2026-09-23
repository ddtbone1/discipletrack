import 'package:discipletrack/core/widgets/step_list.dart';
import 'package:discipletrack/features/onboarding/domain/onboarding_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<StepProgress> statesFor(OnboardingStage stage) =>
      onboardingSteps(stage).map((s) => s.state).toList();

  test('there are always five steps in the same order', () {
    for (final stage in OnboardingStage.values) {
      expect(onboardingSteps(stage).map((s) => s.title), [
        'Account created',
        'Email verified',
        'Join church',
        'Waiting for approval',
        'Ready to begin',
      ]);
    }
  });

  test('join: account and email done, join current, rest upcoming', () {
    expect(statesFor(OnboardingStage.join), const [
      StepProgress.done,
      StepProgress.done,
      StepProgress.current,
      StepProgress.upcoming,
      StepProgress.upcoming,
    ]);
  });

  test('pending: join done, waiting current', () {
    expect(statesFor(OnboardingStage.pending), const [
      StepProgress.done,
      StepProgress.done,
      StepProgress.done,
      StepProgress.current,
      StepProgress.upcoming,
    ]);
  });

  test('ready: everything done except the final step, which is current', () {
    expect(statesFor(OnboardingStage.ready), const [
      StepProgress.done,
      StepProgress.done,
      StepProgress.done,
      StepProgress.done,
      StepProgress.current,
    ]);
  });

  test('the church name labels the join step once a request exists', () {
    final steps = onboardingSteps(
      OnboardingStage.pending,
      churchName: 'Bankal SDA Church',
    );
    expect(steps[2].subtitle, 'Bankal SDA Church');
  });

  test('exactly one step is current at every stage', () {
    for (final stage in OnboardingStage.values) {
      expect(
        statesFor(stage).where((s) => s == StepProgress.current).length,
        1,
        reason: '$stage',
      );
    }
  });
}
