import 'package:discipletrack/core/widgets/app_button.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/onboarding/application/join_church_controller.dart';
import 'package:discipletrack/features/onboarding/presentation/join_church_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  Future<void> findChurch(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Find church'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the join step with the code entry', (tester) async {
    await pumpPage(tester, const JoinChurchPage(), church: null);
    await tester.pumpAndSettle();

    expect(find.text('Join your church'), findsOneWidget);
    expect(find.text('Find church'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join church'), findsNothing);
  });

  testWidgets('uppercases and filters the code as it is typed', (tester) async {
    await pumpPage(tester, const JoinChurchPage(), church: null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '7qk4 mzp2-xr!io01');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '7QK4 MZP2-XR',
    );
  });

  testWidgets('a malformed code is refused locally without a lookup', (
    tester,
  ) async {
    final repo = FakeMembershipRepository();
    await pumpPage(
      tester,
      const JoinChurchPage(),
      church: null,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await findChurch(tester, 'ABC');

    expect(find.text(JoinChurchController.malformedMessage), findsOneWidget);
    expect(repo.lookups, isEmpty);
  });

  testWidgets('an unknown code shows one neutral message', (tester) async {
    final repo = FakeMembershipRepository()..lookupResult = null;
    await pumpPage(
      tester,
      const JoinChurchPage(),
      church: null,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await findChurch(tester, 'ABCDEFGHJK');

    expect(repo.lookups, ['ABCDEFGHJK']);
    expect(find.text(JoinChurchController.notFoundMessage), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join church'), findsNothing);
  });

  testWidgets('a rate limit is reported in words', (tester) async {
    final repo = FakeMembershipRepository()
      ..lookupFailure = const MembershipFailure(
        'Too many attempts. Try again in a few minutes.',
        code: MembershipFailureCode.rateLimited,
      );
    await pumpPage(
      tester,
      const JoinChurchPage(),
      church: null,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await findChurch(tester, 'ABCDEFGHJK');

    expect(
      find.text('Too many attempts. Try again in a few minutes.'),
      findsOneWidget,
    );
  });

  testWidgets('a found church is confirmed by name, then requested with the '
      'same code', (tester) async {
    final repo = FakeMembershipRepository()
      ..lookupResult = sampleChurch
      ..requestOutcome = JoinRequestOutcome.requested;
    await pumpPage(
      tester,
      const JoinChurchPage(),
      church: null,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await findChurch(tester, '7qk4 mzp2-xr');

    expect(find.text('Church found'), findsOneWidget);
    expect(find.text(sampleChurch.name), findsOneWidget);
    expect(find.textContaining('Is this your church?'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join church'), findsOneWidget);
    expect(find.text('Not my church'), findsOneWidget);

    // What the server will see next is the membership created by the request.
    repo.membership = sampleMembership(MembershipStatus.pending);

    await tester.tap(find.widgetWithText(AppButton, 'Join church'));
    await tester.pumpAndSettle();

    expect(repo.requests, [
      (churchId: sampleChurch.id, joinCode: '7QK4MZP2XR'),
    ]);
    expect(
      repo.fetchMembershipCalls,
      1,
      reason: 'the membership is re-read so the router can move on',
    );
  });

  testWidgets('"Not my church" returns to the code entry', (tester) async {
    final repo = FakeMembershipRepository()..lookupResult = sampleChurch;
    await pumpPage(
      tester,
      const JoinChurchPage(),
      church: null,
      membershipRepo: repo,
    );
    await tester.pumpAndSettle();

    await findChurch(tester, 'ABCDEFGHJK');
    await tester.tap(find.text('Not my church'));
    await tester.pumpAndSettle();

    expect(find.text('Find church'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Join church'), findsNothing);
  });

  testWidgets(
    'a closed membership explains that the church must reactivate it',
    (tester) async {
      final repo = FakeMembershipRepository()
        ..lookupResult = sampleChurch
        ..requestOutcome = JoinRequestOutcome.notRequestable;
      await pumpPage(
        tester,
        const JoinChurchPage(),
        church: null,
        membershipRepo: repo,
      );
      await tester.pumpAndSettle();

      await findChurch(tester, 'ABCDEFGHJK');
      await tester.tap(find.widgetWithText(AppButton, 'Join church'));
      await tester.pumpAndSettle();

      expect(
        find.text(JoinChurchController.notRequestableMessage),
        findsOneWidget,
      );
    },
  );
}
