import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership_review/domain/membership_request.dart';
import 'package:discipletrack/features/membership_review/presentation/pending_members_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final _requests = [
  MembershipRequest(
    membershipId: 'm-juan',
    fullName: 'Juan Dela Cruz',
    requestedAt: DateTime.utc(2026, 9, 25, 12),
  ),
  MembershipRequest(
    membershipId: 'm-maria',
    fullName: 'Maria Santos',
    requestedAt: DateTime.utc(2026, 9, 26, 12),
  ),
];

final _approver = sampleMembership(
  MembershipStatus.active,
  onboardingCompletedAt: DateTime.utc(2026, 9, 20),
);

void main() {
  group('PendingMembersPage', () {
    testWidgets('lists each applicant by name and request date', (
      tester,
    ) async {
      final review = FakeMembershipReviewRepository()..pending = _requests;
      await pumpPage(
        tester,
        const PendingMembersPage(),
        membership: _approver,
        reviewRepo: review,
      );
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Requested to join September 25, 2026'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('2 people are waiting to join.'), findsOneWidget);
      // No email is shown; it is not exposed to approvers in this slice.
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('Approve calls the controlled operation for that row', (
      tester,
    ) async {
      final review = FakeMembershipReviewRepository()..pending = _requests;
      await pumpPage(
        tester,
        const PendingMembersPage(),
        membership: _approver,
        reviewRepo: review,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();

      expect(review.approved, ['m-juan']);
      expect(review.rejected, isEmpty);
    });

    testWidgets('Decline asks first and only rejects on confirmation', (
      tester,
    ) async {
      final review = FakeMembershipReviewRepository()..pending = _requests;
      await pumpPage(
        tester,
        const PendingMembersPage(),
        membership: _approver,
        reviewRepo: review,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();
      expect(find.text('Decline this request?'), findsOneWidget);

      await tester.tap(find.text('Keep request'));
      await tester.pumpAndSettle();
      expect(review.rejected, isEmpty);

      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();
      // The dialog's own confirm button shares the label; take the last.
      await tester.tap(find.text('Decline').last);
      await tester.pumpAndSettle();

      expect(review.rejected, ['m-juan']);
    });

    testWidgets('shows an empty state when nobody is waiting', (tester) async {
      final review = FakeMembershipReviewRepository()..pending = const [];
      await pumpPage(
        tester,
        const PendingMembersPage(),
        membership: _approver,
        reviewRepo: review,
      );
      await tester.pumpAndSettle();

      expect(find.text('No pending requests'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });
  });

  group('HomePage approver entry', () {
    testWidgets('an Admin or Coordinator sees Membership requests', (
      tester,
    ) async {
      final review = FakeMembershipReviewRepository()..pending = _requests;
      await pumpPage(
        tester,
        const HomePage(),
        membership: _approver,
        roles: const {ChurchRole.coordinator},
        reviewRepo: review,
      );
      await tester.pumpAndSettle();

      expect(find.text('Membership requests'), findsOneWidget);
      expect(find.text('2 waiting'), findsOneWidget);
    });

    testWidgets('an ordinary member does not', (tester) async {
      await pumpPage(tester, const HomePage(), membership: _approver);
      await tester.pumpAndSettle();

      expect(find.text('Membership requests'), findsNothing);
    });
  });
}
