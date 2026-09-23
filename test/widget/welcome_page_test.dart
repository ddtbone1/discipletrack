import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/onboarding/presentation/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('greets the person by name and church', (tester) async {
    await pumpPage(
      tester,
      const WelcomePage(),
      membership: sampleMembership(MembershipStatus.active),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to the journey, James.'), findsOneWidget);
    expect(find.textContaining(sampleChurch.name), findsOneWidget);
    expect(find.text('Grow. Connect. Disciple.'), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
  });

  testWidgets('Continue records completion on the server, then re-reads the '
      'membership', (tester) async {
    final repo = FakeMembershipRepository()
      ..membership = sampleMembership(MembershipStatus.active);
    await pumpPage(
      tester,
      const WelcomePage(),
      membership: repo.membership,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    // The server would now carry the timestamp.
    repo.membership = sampleMembership(
      MembershipStatus.active,
      onboardingCompletedAt: DateTime.utc(2026, 9, 26),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(repo.completeCalls, 1);
    expect(repo.fetchMembershipCalls, 1);
  });

  testWidgets('a failure keeps the person on the welcome with a message', (
    tester,
  ) async {
    final repo = FakeMembershipRepository()
      ..membership = sampleMembership(MembershipStatus.active)
      ..completeFailure = const MembershipFailure(
        'Could not save your progress right now.',
        code: MembershipFailureCode.network,
      );
    await pumpPage(
      tester,
      const WelcomePage(),
      membership: repo.membership,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save your progress right now.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
  });
}
