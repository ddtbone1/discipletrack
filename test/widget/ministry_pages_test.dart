import 'package:discipletrack/core/widgets/app_text_link.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/ministry/domain/d_group.dart';
import 'package:discipletrack/features/ministry/domain/d_group_detail.dart';
import 'package:discipletrack/features/ministry/domain/d_group_invitation.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/discipler_assignment.dart';
import 'package:discipletrack/features/ministry/domain/member_option.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:discipletrack/features/ministry/presentation/d_group_detail_page.dart';
import 'package:discipletrack/features/ministry/presentation/d_groups_page.dart';
import 'package:discipletrack/features/ministry/presentation/invitation_card.dart';
import 'package:discipletrack/features/ministry/presentation/member_picker_page.dart';
import 'package:discipletrack/features/ministry/presentation/my_group_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const _groupId = 'g0000000-0000-4000-8000-000000000001';
final _now = DateTime.utc(2026, 10, 1, 9);

DGroupMember _member(
  String id,
  String name,
  DGroupResponsibility r, {
  String? membershipId,
  String? phone,
}) => DGroupMember(
  dGroupMembershipId: id,
  churchMembershipId: membershipId ?? 'cm-$id',
  fullName: name,
  responsibility: r,
  phone: phone,
  startedAt: DateTime.utc(2026, 9, 1),
);

/// Leader Ana (who is the signed-in user's membership in Leader tests),
/// Discipler Ben paired with Disciple Cara, unpaired Disciple Dan, and a
/// pending invitation to Eve sent by the sample user.
DGroupDetail _detail() => DGroupDetail(
  group: const DGroup(
    id: _groupId,
    name: 'Young Adults A',
    status: DGroupStatus.active,
  ),
  members: [
    _member('dgm-ana', 'Ana Leader', DGroupResponsibility.leader),
    _member('dgm-ben', 'Ben Discipler', DGroupResponsibility.discipler),
    _member('dgm-cara', 'Cara Disciple', DGroupResponsibility.disciple),
    _member('dgm-dan', 'Dan Disciple', DGroupResponsibility.disciple),
  ],
  assignments: [
    DisciplerAssignment(
      id: 'a1',
      disciplerDGroupMembershipId: 'dgm-ben',
      discipleDGroupMembershipId: 'dgm-cara',
      startedAt: DateTime.utc(2026, 9, 2),
    ),
  ],
  invitations: [
    DGroupInvitation(
      id: 'inv-eve',
      dGroupId: _groupId,
      churchMembershipId: 'cm-eve',
      inviteeName: 'Eve Invitee',
      responsibility: DGroupResponsibility.disciple,
      status: DGroupInvitationStatus.pending,
      invitedBy: sampleUserId,
      createdAt: DateTime.utc(2026, 9, 28),
      expiresAt: DateTime.utc(2026, 10, 12),
    ),
  ],
);

RosterEntry _entry(
  String id,
  String name,
  DGroupResponsibility r, {
  String? phone,
  bool me = false,
  bool leader = false,
  bool discipler = false,
  bool disciple = false,
}) => RosterEntry(
  dGroupMembershipId: 'dgm-$id',
  churchMembershipId: 'cm-$id',
  fullName: name,
  responsibility: r,
  phone: phone,
  isMe: me,
  isMyLeader: leader,
  isMyDiscipler: discipler,
  isMyDisciple: disciple,
);

MinistryContext _leaderContext() => MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [_entry('ana', 'Ana Leader', DGroupResponsibility.leader, me: true)],
);

MinistryContext _discipleContext({bool paired = true}) => MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _entry(
      'ana',
      'Ana Leader',
      DGroupResponsibility.leader,
      phone: '+63 900 111',
      leader: true,
    ),
    _entry(
      'ben',
      'Ben Discipler',
      DGroupResponsibility.discipler,
      phone: paired ? '+63 900 222' : null,
      discipler: paired,
    ),
    _entry('cara', 'Cara Disciple', DGroupResponsibility.disciple, me: true),
    _entry('dan', 'Dan Disciple', DGroupResponsibility.disciple),
  ],
);

MinistryContext _disciplerContext() => MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _entry(
      'ana',
      'Ana Leader',
      DGroupResponsibility.leader,
      phone: '+63 900 111',
      leader: true,
    ),
    _entry('ben', 'Ben Discipler', DGroupResponsibility.discipler, me: true),
    _entry(
      'cara',
      'Cara Disciple',
      DGroupResponsibility.disciple,
      phone: '+63 900 333',
      disciple: true,
    ),
    _entry('dan', 'Dan Disciple', DGroupResponsibility.disciple),
  ],
);

DGroupInvitation _invitation() => DGroupInvitation(
  id: 'inv-1',
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  responsibility: DGroupResponsibility.disciple,
  status: DGroupInvitationStatus.pending,
  invitedByName: 'Ana Leader',
  createdAt: DateTime.utc(2026, 9, 28),
  expiresAt: DateTime.utc(2026, 10, 12),
);

void main() {
  final active = sampleMembership(
    MembershipStatus.active,
    onboardingCompletedAt: DateTime.utc(2026, 9, 1),
  );

  Future<FakeMinistryRepository> pumpDetail(
    WidgetTester tester, {
    required Set<ChurchRole> roles,
    MinistryContext? ministryContext,
  }) async {
    final repo = FakeMinistryRepository()
      ..details = {_groupId: _detail()}
      ..ministryContext = ministryContext;
    await pumpPage(
      tester,
      DGroupDetailPage(groupId: _groupId, now: _now),
      membership: active,
      roles: roles,
      ministryRepo: repo,
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('D Group detail', () {
    testWidgets('the Coordinator sees Change Leader and every management '
        'action, but not Add myself', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});

      expect(find.text('Ana Leader'), findsOneWidget);
      expect(find.text('Change Leader'), findsOneWidget);
      expect(find.text('Invite a member'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Add myself as Discipler'), findsNothing);

      // Pairing state is visible per Disciple.
      expect(find.text('Discipler: Ben Discipler'), findsOneWidget);
      expect(find.text('Not paired yet'), findsOneWidget);
      expect(find.text('Pair'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('the Leader manages their group but cannot change its '
        'Leader', (tester) async {
      await pumpDetail(
        tester,
        roles: const {},
        ministryContext: _leaderContext(),
      );

      expect(find.text('Change Leader'), findsNothing);
      expect(find.text('Add myself as Discipler'), findsOneWidget);
      expect(find.text('Invite a member'), findsOneWidget);
      // Sent by the signed-in Leader, so they may withdraw it.
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('anyone else gets a refusal, not data', (tester) async {
      await pumpPage(
        tester,
        DGroupDetailPage(groupId: _groupId, now: _now),
        membership: active,
        ministryRepo: FakeMinistryRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.text('This D Group isn\'t available'), findsOneWidget);
      expect(find.text('Invite a member'), findsNothing);
    });

    testWidgets('withdrawing is immediate, with no dialog', (tester) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
      );

      await tester.ensureVisible(find.text('Withdraw'));
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.withdrawn, ['inv-eve']);
    });

    testWidgets('pairing progress shows how many Disciples have a '
        'Discipler', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});

      expect(find.text('1 of 2 Disciples paired'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
    });

    testWidgets('removing a Discipler confirms first and mentions the '
        'Disciples who will be unpaired', (tester) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
      );

      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from group'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('1 Disciple paired with them'),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(repo.ended, ['dgm-ben']);
    });

    testWidgets('pairing an unpaired Disciple uses the chosen Discipler', (
      tester,
    ) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
      );

      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben Discipler').last);
      await tester.pumpAndSettle();

      expect(repo.pairings.single, (disciple: 'dgm-dan', discipler: 'dgm-ben'));
    });
  });

  group('DGroupsPage', () {
    testWidgets('lists the members who are not in a D Group, with their '
        'invitation state', (tester) async {
      final repo = FakeMinistryRepository()
        ..placeable = const [
          MemberOption(
            churchMembershipId: 'm1',
            fullName: 'Mara Villanueva',
            hasPendingInvitation: true,
          ),
          MemberOption(
            churchMembershipId: 'm2',
            fullName: 'Paolo Lim',
            hasPendingInvitation: false,
          ),
          MemberOption(
            churchMembershipId: 'm3',
            fullName: 'Cara Placed',
            hasPendingInvitation: false,
            currentDGroupId: _groupId,
            currentDGroupName: 'Young Adults A',
            currentResponsibilities: {DGroupResponsibility.disciple},
          ),
        ];
      await pumpPage(
        tester,
        const DGroupsPage(),
        membership: active,
        roles: const {ChurchRole.coordinator},
        ministryRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('NOT IN A D GROUP'), findsOneWidget);
      expect(find.text('Mara Villanueva'), findsOneWidget);
      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('Paolo Lim'), findsOneWidget);
      expect(find.text('Not invited yet'), findsOneWidget);
      expect(find.text('Cara Placed'), findsNothing);
    });
  });

  group('InvitationCard', () {
    Future<FakeMinistryRepository> pumpCard(WidgetTester tester) async {
      final repo = FakeMinistryRepository()..pendingInvitation = _invitation();
      await pumpPage(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: InvitationCard(invitation: _invitation(), now: _now),
          ),
        ),
        membership: active,
        ministryRepo: repo,
      );
      return repo;
    }

    testWidgets('shows the group, role, inviter and expiry', (tester) async {
      await pumpCard(tester);
      expect(find.text('You\'re invited to Young Adults A'), findsOneWidget);
      expect(
        find.text(
          'Ana Leader invited you to join as a Disciple. Expires in 10 days.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('accept answers immediately', (tester) async {
      final repo = await pumpCard(tester);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(repo.responses.single, (id: 'inv-1', accept: true));
    });

    testWidgets('decline confirms first', (tester) async {
      final repo = await pumpCard(tester);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(repo.responses, isEmpty);

      await tester.tap(find.text('Decline').last);
      await tester.pumpAndSettle();
      expect(repo.responses.single, (id: 'inv-1', accept: false));
    });
  });

  group('MemberPickerPage', () {
    final options = [
      const MemberOption(
        churchMembershipId: 'cm-free',
        fullName: 'Fay Free',
        hasPendingInvitation: false,
      ),
      const MemberOption(
        churchMembershipId: 'cm-pending',
        fullName: 'Pia Pending',
        hasPendingInvitation: true,
      ),
      const MemberOption(
        churchMembershipId: 'cm-placed',
        fullName: 'Paul Placed',
        hasPendingInvitation: false,
        currentDGroupId: 'g-other',
        currentDGroupName: 'Men B',
        currentResponsibilities: {DGroupResponsibility.disciple},
      ),
    ];

    testWidgets('shows why a member cannot be invited, and invites the '
        'chosen one with the chosen role', (tester) async {
      final repo = FakeMinistryRepository()..placeable = options;
      await pumpPage(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const MemberPickerPage(
              purpose: MemberPickPurpose.invite,
              groupId: _groupId,
            ),
          ),
        ),
        membership: active,
        roles: const {ChurchRole.coordinator},
        ministryRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('Has a pending invitation'), findsOneWidget);
      expect(find.text('Already Disciple in Men B'), findsOneWidget);

      // A disabled row does nothing.
      await tester.tap(find.text('Pia Pending'));
      await tester.pumpAndSettle();
      expect(find.text('Invite as Disciple'), findsNothing);

      await tester.tap(find.text('Fay Free'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite as Discipler'));
      await tester.pumpAndSettle();

      expect(repo.invites.single, (
        groupId: _groupId,
        membershipId: 'cm-free',
        role: 'DISCIPLER',
      ));
    });

    testWidgets('search narrows the list', (tester) async {
      final repo = FakeMinistryRepository()..placeable = options;
      await pumpPage(
        tester,
        const MemberPickerPage(
          purpose: MemberPickPurpose.invite,
          groupId: _groupId,
        ),
        membership: active,
        ministryRepo: repo,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'fay');
      await tester.pump();
      expect(find.text('Fay Free'), findsOneWidget);
      expect(find.text('Paul Placed'), findsNothing);
    });
  });

  group('MyGroupPage', () {
    testWidgets('a Disciple sees their Leader and Discipler with phones, '
        'and group mates by name', (tester) async {
      await pumpPage(
        tester,
        const MyGroupPage(),
        membership: active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _discipleContext(),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR LEADER'), findsOneWidget);
      expect(find.text('+63 900 111'), findsOneWidget);
      expect(find.text('YOUR DISCIPLER'), findsOneWidget);
      expect(find.text('+63 900 222'), findsOneWidget);
      expect(find.text('Dan Disciple'), findsOneWidget);
      expect(find.text('YOUR DISCIPLES'), findsNothing);
    });

    testWidgets('an unpaired Disciple is told so', (tester) async {
      await pumpPage(
        tester,
        const MyGroupPage(),
        membership: active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _discipleContext(paired: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not paired yet'), findsOneWidget);
    });

    testWidgets('a Discipler sees Your Disciples with their phones', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const MyGroupPage(),
        membership: active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _disciplerContext(),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR DISCIPLES'), findsOneWidget);
      expect(find.text('Cara Disciple'), findsOneWidget);
      expect(find.text('+63 900 333'), findsOneWidget);
      expect(find.text('YOUR DISCIPLER'), findsNothing);
    });
  });

  group('Home entries', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      Set<ChurchRole> roles = const {},
      MinistryContext? ministryContext,
      DGroupInvitation? invitation,
    }) async {
      await pumpPage(
        tester,
        const HomePage(),
        membership: active,
        roles: roles,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = ministryContext
          ..pendingInvitation = invitation,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Coordinator: the D Groups row', (tester) async {
      await pumpHome(tester, roles: const {ChurchRole.coordinator});
      expect(find.text('D Groups'), findsOneWidget);
    });

    testWidgets('an ordinary member gets no D Groups row', (tester) async {
      await pumpHome(tester);
      expect(find.text('D Groups'), findsNothing);
      expect(find.text('Not placed in a D Group yet'), findsOneWidget);
    });

    testWidgets('Leader: the My D Group row', (tester) async {
      await pumpHome(tester, ministryContext: _leaderContext());
      expect(find.text('MY D GROUP'), findsOneWidget);
      expect(find.text('Young Adults A'), findsOneWidget);
    });

    testWidgets('Disciple: the group card with Leader and Discipler', (
      tester,
    ) async {
      await pumpHome(tester, ministryContext: _discipleContext());
      expect(find.text('Leader: Ana Leader'), findsOneWidget);
      expect(find.text('Discipler: Ben Discipler'), findsOneWidget);
    });

    testWidgets('Disciple without a Discipler: "not paired yet"', (
      tester,
    ) async {
      await pumpHome(tester, ministryContext: _discipleContext(paired: false));
      expect(find.text('Not paired with a Discipler yet'), findsOneWidget);
    });

    testWidgets('Invitee: the invitation card', (tester) async {
      await pumpHome(tester, invitation: _invitation());
      expect(find.byType(InvitationCard), findsOneWidget);
      expect(find.text('Not placed in a D Group yet'), findsNothing);
    });
  });

  group('AppTextLink on detail', () {
    testWidgets('Change Leader is a text link', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});
      expect(find.widgetWithText(AppTextLink, 'Change Leader'), findsOneWidget);
    });
  });
}
