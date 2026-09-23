import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/onboarding/presentation/pending_approval_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('names the church and the request date', (tester) async {
    await pumpPage(
      tester,
      const PendingApprovalPage(),
      membership: sampleMembership(
        MembershipStatus.pending,
        requestedAt: DateTime.utc(2026, 9, 25, 12),
      ),
    );
    await tester.pumpAndSettle();

    // Page title and the current timeline step share the wording.
    expect(find.text('Waiting for approval'), findsNWidgets(2));
    expect(find.textContaining(sampleChurch.name), findsWidgets);
    expect(find.textContaining('Sent Sep 25'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsOneWidget);
  });

  testWidgets('"Check status" re-reads the membership on demand', (
    tester,
  ) async {
    final repo = FakeMembershipRepository()
      ..membership = sampleMembership(MembershipStatus.pending);
    await pumpPage(
      tester,
      const PendingApprovalPage(),
      membership: repo.membership,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Check status'));
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();

    expect(repo.fetchMembershipCalls, 1);
    expect(find.text('Still waiting'), findsOneWidget);
  });

  testWidgets('polls for approval while the screen is open', (tester) async {
    final repo = FakeMembershipRepository()
      ..membership = sampleMembership(MembershipStatus.pending);
    await pumpPage(
      tester,
      const PendingApprovalPage(),
      membership: repo.membership,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();
    expect(repo.fetchMembershipCalls, 0);

    await tester.pump(PendingApprovalPage.pollInterval);
    await tester.pump();
    expect(repo.fetchMembershipCalls, 1);

    await tester.pump(PendingApprovalPage.pollInterval);
    await tester.pump();
    expect(repo.fetchMembershipCalls, 2);
  });
}
