// Slice 8 (ADR-022, UI_DESIGN_SYSTEM section 70): the Platform area, the
// Coordinator's Church information, the church unavailable screen and the
// Profile entries to them.
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership/presentation/church_info_page.dart';
import 'package:discipletrack/features/membership/presentation/church_unavailable_page.dart';
import 'package:discipletrack/features/platform/domain/platform_models.dart';
import 'package:discipletrack/features/platform/presentation/new_church_page.dart';
import 'package:discipletrack/features/platform/presentation/platform_church_page.dart';
import 'package:discipletrack/features/platform/presentation/platform_churches_page.dart';
import 'package:discipletrack/features/profile/presentation/profile_page.dart';
import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final _active = sampleMembership(
  MembershipStatus.active,
  joinedAt: DateTime.utc(2026, 3, 1),
  onboardingCompletedAt: DateTime.utc(2026, 3, 1),
);

const _superAdmin = {PlatformRole.superAdmin};

void main() {
  group('Churches', () {
    testWidgets('lists each church with its status, counts and Coordinator; '
        'archived ones are kept apart', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [
          samplePlatformChurch(),
          samplePlatformChurch(
            id: 'church-2',
            name: 'Hope Church',
            status: ChurchStatus.suspended,
          ),
          samplePlatformChurch(
            id: 'church-3',
            name: 'Old Church',
            status: ChurchStatus.archived,
          ),
        ];
      await pumpPage(
        tester,
        const PlatformChurchesPage(),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('The churches on DiscipleTrack.'), findsOne);
      expect(find.text('Grace Church'), findsOne);
      expect(find.text('Hope Church'), findsOne);
      expect(find.text('Suspended'), findsOne);
      expect(find.text('24 members · 3 D Groups'), findsWidgets);
      expect(find.text('Ana Reyes'), findsWidgets);
      expect(find.text('Archived (1)'), findsOne);
      expect(find.text('Old Church'), findsNothing, reason: 'collapsed');
      expect(find.text('New church'), findsOne);
    });

    testWidgets('with no churches says what to do', (tester) async {
      await pumpPage(
        tester,
        const PlatformChurchesPage(),
        church: null,
        platformRoles: _superAdmin,
      );
      await tester.pumpAndSettle();
      expect(find.text('No churches yet'), findsOne);
    });

    testWidgets('without the platform role nothing is listed', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()];
      await pumpPage(tester, const PlatformChurchesPage(), platformRepo: repo);
      await tester.pumpAndSettle();
      expect(find.text('Grace Church'), findsNothing);
    });
  });

  group('New church (a stepper of pages)', () {
    GoRouter flow() => GoRouter(
      initialLocation: Routes.platformNewChurch,
      routes: [
        GoRoute(
          path: Routes.platform,
          builder: (_, _) => const Text('Churches page'),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const NewChurchPage(),
              routes: [
                GoRoute(
                  path: 'coordinator',
                  builder: (_, _) => const NewChurchCoordinatorPage(),
                ),
                GoRoute(
                  path: 'confirm',
                  builder: (_, _) => const NewChurchConfirmPage(),
                ),
              ],
            ),
            GoRoute(
              path: 'created',
              builder: (_, s) =>
                  NewChurchDonePage(created: s.extra as CreatedChurch?),
            ),
            GoRoute(
              path: 'churches/:churchId',
              builder: (_, s) => Text('Detail ${s.pathParameters['churchId']}'),
            ),
          ],
        ),
      ],
    );

    testWidgets('name, then the Coordinator confirmed by name, then one '
        'create: each step its own page with the indicator at the top', (
      tester,
    ) async {
      final repo = FakePlatformRepository()
        ..previews = {'ana@example.test': foundAccount};
      await pumpPage(
        tester,
        const SizedBox(),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
        router: flow(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsNothing, reason: 'one text span');
      expect(find.textContaining('Step 1 of 3'), findsOne);
      expect(find.text('Name the church'), findsOne);
      await tester.enterText(find.byType(TextField), 'Grace Church');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 2 of 3'), findsOne);
      expect(find.text('Grace Church'), findsOne);
      await tester.enterText(find.byType(TextField), 'ana@example.test');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 3 of 3'), findsOne);
      expect(find.text('Create Grace Church?'), findsOne);
      expect(find.text('Ana Reyes  ·  Coordinator'), findsOne);
      expect(find.text('ana@example.test'), findsOne);
      expect(repo.calls.where((c) => c.startsWith('create')), isEmpty);

      await tester.tap(find.text('Create church'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('create:Grace Church:ana@example.test'));
      expect(find.text('Grace Church is ready'), findsOne);
      expect(find.text('ABCDE 23456'), findsOne);
      expect(find.textContaining('Ana can find this code'), findsOne);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Detail church-new'), findsOne);
    });

    testWidgets('back from a created church returns to the list, not into '
        'the finished stepper', (tester) async {
      final router = flow();
      await pumpPage(
        tester,
        const SizedBox(),
        church: null,
        platformRoles: _superAdmin,
        router: router,
      );
      await tester.pumpAndSettle();
      router.go(
        Routes.platformNewChurchDone,
        extra: (
          churchId: 'church-new',
          churchName: 'Grace Church',
          joinCode: 'ABCDE23456',
          coordinatorName: 'Ana Reyes',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Grace Church is ready'), findsOne);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Churches page'), findsOne);
      expect(find.text('Name the church'), findsNothing);
    });

    testWidgets('a blank name is refused in words, and the error clears as '
        'the name is typed', (tester) async {
      await pumpPage(
        tester,
        const SizedBox(),
        church: null,
        platformRoles: _superAdmin,
        router: flow(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the church name.'), findsOne);
      await tester.enterText(find.byType(TextField), 'G');
      await tester.pump();
      expect(find.text('Enter the church name.'), findsNothing);
    });

    testWidgets('an email of no registered account stops at step 2, before '
        'anything is created', (tester) async {
      final repo = FakePlatformRepository();
      await pumpPage(
        tester,
        const SizedBox(),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
        router: flow(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Grace Church');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nobody@example.test');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No DiscipleTrack account uses that email. Ask them to register '
          'first.',
        ),
        findsOne,
      );
      expect(find.textContaining('Step 2 of 3'), findsOne);
      expect(repo.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('the confirm step without a draft starts again', (
      tester,
    ) async {
      final router = flow()..go(Routes.platformNewChurchConfirm);
      await pumpPage(
        tester,
        const SizedBox(),
        church: null,
        platformRoles: _superAdmin,
        router: router,
      );
      await tester.pumpAndSettle();
      expect(find.text('Start from the name'), findsOne);
      expect(find.text('Create church'), findsNothing);
    });
  });

  group('Church detail', () {
    testWidgets('regenerating the code asks first; cancelling changes '
        'nothing, confirming changes it', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()];
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('7QK4M ZP2XR'), findsOne);

      await tester.ensureVisible(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The current code stops working at once'),
        findsOne,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isNot(contains('regenerate')));

      await tester.ensureVisible(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change code'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('regenerate'));
      expect(find.text('Join code changed'), findsOne);
    });

    testWidgets('suspending explains what members see and asks first', (
      tester,
    ) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()];
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Suspend church'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Suspend church'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          "Members can still sign in but won't see the church",
        ),
        findsOne,
      );
      await tester.tap(find.text('Suspend'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('status:SUSPENDED'));
    });

    testWidgets('archiving asks first, and its final action is in the '
        'error colour, like the button that opened it', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()];
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Archive church'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Archive church'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Archiving is final in the app'), findsOne);

      final action = find.widgetWithText(TextButton, 'Archive');
      final context = tester.element(action);
      expect(
        tester.widget<TextButton>(action).style?.foregroundColor?.resolve({}),
        context.palette.error,
      );
      expect(repo.calls, isNot(contains('status:ARCHIVED')));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('status:ARCHIVED'));
    });

    testWidgets('the only Coordinator can be replaced but not removed', (
      tester,
    ) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()];
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Coordinator actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Coordinator actions'));
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOne);
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('a refusal is shown in its own words', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch()]
        ..failure = PlatformFailure(
          PlatformFailure.messageFor('last_coordinator')!,
          reason: 'last_coordinator',
        );
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change code'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'An active church needs a Coordinator. Replace this one instead.',
        ),
        findsOne,
      );
    });

    testWidgets('an archived church shows no actions', (tester) async {
      final repo = FakePlatformRepository()
        ..churches = [samplePlatformChurch(status: ChurchStatus.archived)];
      await pumpPage(
        tester,
        const PlatformChurchPage(churchId: 'church-1'),
        church: null,
        platformRoles: _superAdmin,
        platformRepo: repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Regenerate code'), findsNothing);
      expect(find.text('Add Coordinator'), findsNothing);
      expect(find.text('Suspend church', skipOffstage: false), findsNothing);
      expect(find.byTooltip('Coordinator actions'), findsNothing);
      expect(
        find.textContaining(
          "archived, so it can't be changed",
          skipOffstage: false,
        ),
        findsOne,
      );
    });
  });

  group('Church information', () {
    testWidgets('the Coordinator sees the join code with Copy, and no way to '
        'change it', (tester) async {
      final repo = FakeMembershipRepository()
        ..joinCode = ChurchJoinCode(
          code: '7QK4MZP2XR',
          setAt: DateTime.utc(2026, 10, 1),
        );
      await pumpPage(
        tester,
        const ChurchInfoPage(),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        membershipRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('7QK4M ZP2XR'), findsOne);
      expect(find.text('Copy'), findsOne);
      expect(
        find.text('Only the DiscipleTrack administrator can change this code.'),
        findsOne,
      );
      expect(find.textContaining('Regenerate'), findsNothing);
    });

    testWidgets('anyone else sees the restricted state, never the code', (
      tester,
    ) async {
      final repo = FakeMembershipRepository()
        ..joinCode = const ChurchJoinCode(code: '7QK4MZP2XR');
      await pumpPage(
        tester,
        const ChurchInfoPage(),
        membership: _active,
        membershipRepo: repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('7QK4M ZP2XR'), findsNothing);
      expect(repo.joinCodeReads, 0, reason: 'not even asked for');
      expect(
        find.text("The join code is shown to the church's Coordinator."),
        findsOne,
      );
    });
  });

  group('Church unavailable', () {
    testWidgets('names the church and keeps the profile and sign-out', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ChurchUnavailablePage(),
        membership: _active,
        church: const ChurchSummary(
          id: sampleChurchId,
          name: 'Grace Church',
          status: ChurchStatus.suspended,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This church is unavailable'), findsOne);
      expect(
        find.text(
          "Grace Church isn't available on DiscipleTrack right now. Nothing "
          'has been deleted. You can still update your profile.',
        ),
        findsOne,
      );
      expect(find.text('Profile'), findsOne);
      expect(find.text('Try again'), findsOne);
      expect(find.text('Sign out'), findsOne);
      expect(find.text('Platform'), findsNothing);
    });

    testWidgets('an archived church reads as closed; a Super Admin keeps the '
        'Platform', (tester) async {
      await pumpPage(
        tester,
        const ChurchUnavailablePage(),
        membership: _active,
        church: const ChurchSummary(
          id: sampleChurchId,
          name: 'Grace Church',
          status: ChurchStatus.archived,
        ),
        platformRoles: _superAdmin,
      );
      await tester.pumpAndSettle();
      expect(find.text('This church is closed'), findsOne);
      expect(find.text('Platform'), findsOne);
    });
  });

  group('Profile', () {
    testWidgets('the Coordinator finds Church information; a Super Admin the '
        'Platform', (tester) async {
      await pumpPage(
        tester,
        const ProfilePage(),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        platformRoles: _superAdmin,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Administration'), 200);
      expect(find.text('Church information'), findsOne);
      expect(find.text('Platform'), findsOne);
    });

    testWidgets('an ordinary member sees neither', (tester) async {
      await pumpPage(tester, const ProfilePage(), membership: _active);
      await tester.pumpAndSettle();
      expect(find.text('Administration', skipOffstage: false), findsNothing);
    });
  });
}
