import 'package:discipletrack/core/widgets/app_text_link.dart';
import 'package:discipletrack/features/discipleship/domain/disciple_progress_summary.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/ministry/data/ministry_repository.dart';
import 'package:discipletrack/features/ministry/domain/d_group.dart';
import 'package:discipletrack/features/ministry/domain/d_group_detail.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/d_group_placement.dart';
import 'package:discipletrack/features/ministry/domain/discipler_assignment.dart';
import 'package:discipletrack/features/ministry/domain/discipler_candidate.dart';
import 'package:discipletrack/features/ministry/domain/member_option.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:discipletrack/features/ministry/presentation/add_members_page.dart';
import 'package:discipletrack/features/ministry/presentation/d_group_detail_page.dart';
import 'package:discipletrack/features/ministry/presentation/d_groups_page.dart';
import 'package:discipletrack/features/ministry/presentation/my_group_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const _groupId = 'g0000000-0000-4000-8000-000000000001';

DGroupMember _member(
  String key,
  String name,
  DGroupResponsibility r, {
  String? phone,
}) => DGroupMember(
  dGroupMembershipId: '${r.toDb}-$key',
  churchMembershipId: 'cm-$key',
  fullName: name,
  responsibility: r,
  phone: phone,
  startedAt: DateTime.utc(2026, 9, 1),
  disciplerBasis: r == DGroupResponsibility.discipler
      ? DisciplerBasis.initialRollout
      : null,
);

DGroupPlacement _placement(String key, String name) => DGroupPlacement(
  placementId: 'pl-$key',
  churchMembershipId: 'cm-$key',
  fullName: name,
  startedAt: DateTime.utc(2026, 9, 1),
);

/// Leader Ana, Discipler Ben paired with Disciple Cara, unpaired Disciple
/// Dan, and Eve, who was added and still needs setup. With [danDisciples],
/// Dan is also a Discipler (ADR-012).
DGroupDetail _detail({bool danDisciples = false}) => DGroupDetail(
  group: const DGroup(
    id: _groupId,
    name: 'Young Adults A',
    status: DGroupStatus.active,
  ),
  placements: [
    _placement('ana', 'Ana Leader'),
    _placement('ben', 'Ben Discipler'),
    _placement('cara', 'Cara Disciple'),
    _placement('dan', 'Dan Disciple'),
    _placement('eve', 'Eve Newcomer'),
  ],
  members: [
    _member('ana', 'Ana Leader', DGroupResponsibility.leader),
    _member('ben', 'Ben Discipler', DGroupResponsibility.discipler),
    _member('cara', 'Cara Disciple', DGroupResponsibility.disciple),
    _member('dan', 'Dan Disciple', DGroupResponsibility.disciple),
    if (danDisciples)
      _member('dan', 'Dan Disciple', DGroupResponsibility.discipler),
  ],
  assignments: [
    DisciplerAssignment(
      id: 'a1',
      disciplerDGroupMembershipId: 'DISCIPLER-ben',
      discipleDGroupMembershipId: 'DISCIPLE-cara',
      startedAt: DateTime.utc(2026, 9, 2),
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

MinistryContext _needsSetupContext() => MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _entry('ana', 'Ana Leader', DGroupResponsibility.leader, leader: true),
  ],
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

void main() {
  final active = sampleMembership(
    MembershipStatus.active,
    onboardingCompletedAt: DateTime.utc(2026, 9, 1),
  );

  Future<FakeMinistryRepository> pumpDetail(
    WidgetTester tester, {
    required Set<ChurchRole> roles,
    MinistryContext? ministryContext,
    DGroupDetail? detail,
    bool setupOpen = true,
    List<DisciplerCandidate> candidates = const [],
  }) async {
    final repo = FakeMinistryRepository()
      ..details = {_groupId: detail ?? _detail()}
      ..ministryContext = ministryContext
      ..setupStatus = InitialSetupStatus(isOpen: setupOpen)
      ..candidates = candidates;
    await pumpPage(
      tester,
      const DGroupDetailPage(groupId: _groupId),
      membership: active,
      roles: roles,
      ministryRepo: repo,
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openMenuOf(WidgetTester tester, String name) async {
    final row = find.ancestor(
      of: find.text(name),
      matching: find.byType(InkWell),
    );
    final menu = find.descendant(
      of: row.first,
      matching: find.byTooltip('More actions'),
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  group('D Group detail', () {
    testWidgets('the Coordinator sees Change Leader and every management '
        'action, but not Add myself', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});

      expect(find.text('Ana Leader'), findsOneWidget);
      expect(find.text('Change Leader'), findsOneWidget);
      expect(find.text('Add members'), findsOneWidget);
      expect(find.text('Add myself as Discipler'), findsNothing);

      // Pairing state is visible per Disciple.
      expect(find.text('with Ben Discipler'), findsOneWidget);
      expect(find.text('Not paired yet'), findsOneWidget);
      expect(find.byTooltip('Pair'), findsOneWidget);
      expect(find.byTooltip('Change Discipler'), findsOneWidget);

      // Eve was added and waits for setup.
      expect(find.text('Eve Newcomer'), findsOneWidget);
      expect(find.text('Needs setup'), findsOneWidget);
      expect(find.byTooltip('Set up'), findsOneWidget);
    });

    testWidgets('the Leader manages their group but cannot change its '
        'Leader', (tester) async {
      await pumpDetail(
        tester,
        roles: const {},
        ministryContext: _leaderContext(),
      );

      expect(find.text('Change Leader'), findsNothing);
      // Every Leader is already a Discipler (ADR-020): no self-add.
      expect(find.text('Add myself as Discipler'), findsNothing);
      expect(find.text('Add members'), findsOneWidget);
      expect(find.byTooltip('Set up'), findsOneWidget);
    });

    testWidgets('filters show counts and narrow the list', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});

      expect(find.text('All 4'), findsOneWidget);
      expect(find.text('Disciples 2'), findsOneWidget);
      expect(find.text('Disciplers 1'), findsOneWidget);
      expect(find.text('Needs setup 1'), findsOneWidget);

      await tester.tap(find.text('Needs setup 1'));
      await tester.pumpAndSettle();
      expect(find.text('Eve Newcomer'), findsOneWidget);
      expect(find.text('Cara Disciple'), findsNothing);

      await tester.tap(find.text('Disciplers 1'));
      await tester.pumpAndSettle();
      expect(find.text('Ben Discipler'), findsOneWidget);
      expect(find.text('Eve Newcomer'), findsNothing);
    });

    testWidgets('the Coordinator sees each Disciple\'s progress', (
      tester,
    ) async {
      final repo = FakeMinistryRepository()..details = {_groupId: _detail()};
      await pumpPage(
        tester,
        const DGroupDetailPage(groupId: _groupId),
        membership: active,
        roles: const {ChurchRole.coordinator},
        ministryRepo: repo,
        discipleshipRepo: FakeDiscipleshipRepository()
          ..groupProgress = {
            _groupId: [
              const DiscipleProgressSummary(
                membershipId: 'cm-cara',
                fullName: 'Cara Disciple',
                lessonsTotal: 10,
                lessonsCompleted: 3,
                creditedCount: 1,
                recordedAbsences: 0,
                currentLessonNumber: 4,
              ),
            ],
          },
      );
      await tester.pumpAndSettle();

      // The lesson is coloured text on the row (UI_DESIGN_SYSTEM section 39).
      expect(find.text('Lesson 4 of 10'), findsOneWidget);
      // Dan has no progress row, so his row stays a plain face.
      expect(find.text('Dan Disciple'), findsOneWidget);
    });

    testWidgets('a refused progress read leaves plain rows, with no error', (
      tester,
    ) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});
      expect(find.text('Cara Disciple'), findsWidgets);
      expect(find.textContaining('Lesson '), findsNothing);
      expect(find.textContaining("can't"), findsNothing);
    });

    testWidgets('anyone else gets a refusal, not data', (tester) async {
      await pumpPage(
        tester,
        const DGroupDetailPage(groupId: _groupId),
        membership: active,
        ministryRepo: FakeMinistryRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.text('This D Group isn\'t available'), findsOneWidget);
      expect(find.text('Add members'), findsNothing);
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

      await openMenuOf(tester, 'Ben Discipler');
      await tester.tap(find.text('Remove from group'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('1 Disciple paired with them'),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(repo.removed, ['pl-ben']);
    });

    testWidgets('pairing an unpaired Disciple uses the chosen Discipler', (
      tester,
    ) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
      );

      await tapVisible(tester, find.byTooltip('Pair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben Discipler').last);
      await tester.pumpAndSettle();

      expect(repo.pairings.single, (
        disciple: 'DISCIPLE-dan',
        discipler: 'DISCIPLER-ben',
      ));
    });

    testWidgets('a Disciple who is also a Discipler is never offered as '
        'their own Discipler', (tester) async {
      await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
        detail: _detail(danDisciples: true),
      );

      await tapVisible(tester, find.byTooltip('Pair'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Ben Discipler')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Dan Disciple')),
        findsNothing,
      );
    });

    testWidgets('setting up a newcomer as a Disciple', (tester) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
      );

      await tapVisible(tester, find.byTooltip('Set up'));
      await tester.pumpAndSettle();
      expect(find.text('Set up Eve Newcomer'), findsOneWidget);
      expect(find.text('Existing Discipler'), findsOneWidget);

      await tester.tap(find.text('Disciple').last);
      await tester.pumpAndSettle();
      expect(repo.setUps.single, (placementId: 'pl-eve', role: 'DISCIPLE'));
    });

    testWidgets('once the setup period is closed, Existing Discipler is '
        'shown with the reason and cannot be chosen', (tester) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
        setupOpen: false,
      );

      await tapVisible(tester, find.byTooltip('Set up'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The setup period has ended'), findsOneWidget);

      await tester.tap(find.text('Existing Discipler'));
      await tester.pumpAndSettle();
      expect(repo.setUps, isEmpty);
    });

    testWidgets('a Disciple can be recognized as an Existing Discipler only '
        'while the setup period is open', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});
      await openMenuOf(tester, 'Dan Disciple');
      expect(find.text('Recognize as Existing Discipler'), findsOneWidget);
    });

    testWidgets('no recognition offer once the setup period is closed', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
        setupOpen: false,
      );
      await openMenuOf(tester, 'Dan Disciple');
      expect(find.text('Recognize as Existing Discipler'), findsNothing);
      expect(find.text('Remove from group'), findsOneWidget);
    });
  });

  group('Eligibility and appointment', () {
    final cara = DisciplerCandidate(
      churchMembershipId: 'cm-cara',
      fullName: 'Cara Disciple',
      dGroupId: _groupId,
      dGroupName: 'Young Adults A',
      eligibleSince: DateTime.utc(2026, 9, 30, 12),
    );

    testWidgets('an eligible Disciple is marked, and eligible is not shown '
        'as Discipler', (tester) async {
      await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
        candidates: [cara],
      );
      // A short badge; the date lives on the D Groups page.
      expect(find.text('Eligible'), findsOneWidget);
      await tester.tap(find.text('Disciplers 1'));
      await tester.pumpAndSettle();
      expect(find.text('Cara Disciple'), findsNothing);
    });

    testWidgets('the Leader sees eligibility but cannot appoint', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        roles: const {},
        ministryContext: _leaderContext(),
        candidates: [cara],
      );
      expect(find.text('Eligible'), findsOneWidget);
      await openMenuOf(tester, 'Cara Disciple');
      expect(find.text('Appoint as Discipler'), findsNothing);
    });

    testWidgets('the Coordinator appoints after confirming', (tester) async {
      final repo = await pumpDetail(
        tester,
        roles: const {ChurchRole.coordinator},
        candidates: [cara],
      );
      await openMenuOf(tester, 'Cara Disciple');
      await tester.tap(find.text('Appoint as Discipler'));
      await tester.pumpAndSettle();
      expect(find.textContaining('They stay a Disciple'), findsOneWidget);
      expect(repo.appointed, isEmpty);

      await tester.tap(find.text('Appoint'));
      await tester.pumpAndSettle();
      expect(repo.appointed, ['cm-cara']);
    });

    testWidgets('the D Groups page lists everyone eligible, church-wide', (
      tester,
    ) async {
      final repo = FakeMinistryRepository()..candidates = [cara];
      await pumpPage(
        tester,
        const DGroupsPage(),
        membership: active,
        roles: const {ChurchRole.coordinator},
        ministryRepo: repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Eligible to disciple'), findsOneWidget);
      expect(
        find.textContaining('Young Adults A · eligible since'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Appoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appoint').last);
      await tester.pumpAndSettle();
      expect(repo.appointed, ['cm-cara']);
    });
  });

  group('AddMembersPage', () {
    final addable = [
      AddableMember(
        churchMembershipId: 'cm-mara',
        fullName: 'Mara Villanueva',
        joinedAt: DateTime.utc(2026, 9, 14),
      ),
      const AddableMember(
        churchMembershipId: 'cm-paolo',
        fullName: 'Paolo Lim',
      ),
      const AddableMember(churchMembershipId: 'cm-rosa', fullName: 'Rosa Diaz'),
    ];

    Future<(FakeMinistryRepository, List<int?>)> pumpAdd(
      WidgetTester tester, {
      List<AddableMember>? members,
    }) async {
      final repo = FakeMinistryRepository()..addable = members ?? addable;
      final popped = <int?>[];
      await pumpPage(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    popped.add(
                      await Navigator.of(context).push<int>(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AddMembersPage(groupId: _groupId),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        membership: active,
        roles: const {ChurchRole.coordinator},
        ministryRepo: repo,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (repo, popped);
    }

    testWidgets('choosing several and adding them in one step', (tester) async {
      final (repo, popped) = await pumpAdd(tester);

      expect(find.text('3 members in no D Group'), findsOneWidget);
      expect(find.text('No one chosen yet'), findsOneWidget);

      await tester.tap(find.text('Mara Villanueva'));
      await tester.tap(find.text('Rosa Diaz'));
      await tester.pump();
      expect(find.text('2 chosen'), findsOneWidget);

      await tester.tap(find.text('Add 2'));
      await tester.pumpAndSettle();

      expect(repo.added.single.groupId, _groupId);
      expect(repo.added.single.membershipIds, ['cm-mara', 'cm-rosa']);
      expect(popped, [2]);
    });

    testWidgets('search narrows the list and keeps the selection', (
      tester,
    ) async {
      await pumpAdd(tester);
      await tester.tap(find.text('Paolo Lim'));
      await tester.enterText(find.byType(TextField), 'mar');
      await tester.pump();

      expect(find.text('Mara Villanueva'), findsOneWidget);
      expect(find.text('Paolo Lim'), findsNothing);
      expect(find.text('1 chosen'), findsOneWidget);
    });

    testWidgets('clear empties the selection', (tester) async {
      await pumpAdd(tester);
      await tester.tap(find.text('Paolo Lim'));
      await tester.pump();
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.text('No one chosen yet'), findsOneWidget);
    });

    testWidgets('says so when everyone is already in a group', (tester) async {
      await pumpAdd(tester, members: const []);
      expect(find.text('Everyone is already in a D Group'), findsOneWidget);
    });

    testWidgets('a refusal keeps the page open with the reason', (
      tester,
    ) async {
      final (repo, popped) = await pumpAdd(tester);
      repo.actionFailure = const MinistryFailure(
        'Someone you chose was just added to another D Group.',
      );
      await tester.tap(find.text('Mara Villanueva'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add members'), findsOneWidget);
      expect(
        find.text('Someone you chose was just added to another D Group.'),
        findsOneWidget,
      );
      expect(popped, isEmpty);
    });
  });

  group('DGroupsPage', () {
    Future<FakeMinistryRepository> pumpGroups(
      WidgetTester tester, {
      bool setupOpen = true,
    }) async {
      final repo = FakeMinistryRepository()
        ..setupStatus = InitialSetupStatus(
          isOpen: setupOpen,
          closedAt: setupOpen ? null : DateTime.utc(2026, 10, 2),
        )
        ..placeable = const [
          MemberOption(churchMembershipId: 'm1', fullName: 'Mara Villanueva'),
          MemberOption(
            churchMembershipId: 'm3',
            fullName: 'Cara Placed',
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
      return repo;
    }

    testWidgets('lists the members who are not in a D Group', (tester) async {
      await pumpGroups(tester);

      expect(find.text('Not in a D Group'), findsOneWidget);
      expect(find.text('Mara Villanueva'), findsOneWidget);
      expect(find.text('Cara Placed'), findsNothing);
    });

    testWidgets('closing the setup period is confirmed', (tester) async {
      final repo = await pumpGroups(tester);

      expect(find.text('Initial setup period'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      await tester.ensureVisible(find.text('Close setup period'));
      await tester.tap(find.text('Close setup period'));
      await tester.pumpAndSettle();
      expect(repo.windowChanges, isEmpty);

      await tester.tap(find.text('Close setup period').last);
      await tester.pumpAndSettle();
      expect(repo.windowChanges, [false]);
    });

    testWidgets('a closed period can be reopened', (tester) async {
      await pumpGroups(tester, setupOpen: false);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
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

      expect(find.text('Your Leader'), findsOneWidget);
      expect(find.text('+63 900 111'), findsOneWidget);
      expect(find.text('Your Discipler'), findsOneWidget);
      expect(find.text('+63 900 222'), findsOneWidget);
      expect(find.text('Dan Disciple'), findsOneWidget);
      expect(find.text('Your Disciples'), findsNothing);
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

      expect(find.text('Your Disciples'), findsOneWidget);
      expect(find.text('Cara Disciple'), findsOneWidget);
      expect(find.text('+63 900 333'), findsOneWidget);
      expect(find.text('Your Discipler'), findsNothing);
    });

    testWidgets('a Leader uses the same roster, as a Discipler, with Manage '
        'members added (ADR-020)', (tester) async {
      await pumpPage(
        tester,
        const MyGroupPage(),
        membership: active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = MinistryContext(
            dGroupId: _groupId,
            dGroupName: 'Young Adults A',
            roster: [
              _entry(
                'ana',
                'Ana Leader',
                DGroupResponsibility.leader,
                me: true,
              ),
              _entry(
                'ana',
                'Ana Leader',
                DGroupResponsibility.discipler,
                me: true,
              ),
            ],
          ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage members'), findsOneWidget);
      expect(find.text('Your Disciples'), findsOneWidget);
      expect(find.text('Your Leader'), findsNothing);
      // Roles are coloured text, never pills (UI_DESIGN_SYSTEM section 39).
      expect(find.text('You · Leader'), findsOneWidget);
    });

    testWidgets('someone not set up yet sees their group and Leader only', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const MyGroupPage(),
        membership: active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _needsSetupContext(),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're in Young Adults A"), findsOneWidget);
      expect(find.textContaining('Ana Leader, your Leader'), findsOneWidget);
      expect(find.text('Your Leader'), findsNothing);
    });
  });

  group('Home entries', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      Set<ChurchRole> roles = const {},
      MinistryContext? ministryContext,
    }) async {
      await pumpPage(
        tester,
        const HomePage(),
        membership: active,
        roles: roles,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = ministryContext,
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
      expect(find.text('Not in a D Group yet'), findsOneWidget);
    });

    testWidgets('Leader: the My D Group row', (tester) async {
      await pumpHome(tester, ministryContext: _leaderContext());
      expect(find.text('My D Group'), findsOneWidget);
      expect(find.text('Young Adults A'), findsOneWidget);
    });

    testWidgets('the member count includes people not set up yet', (
      tester,
    ) async {
      // The roster holds only the Leader; the group has 11 people placed.
      await pumpHome(
        tester,
        ministryContext: MinistryContext(
          dGroupId: _groupId,
          dGroupName: 'Young Adults A',
          memberCount: 11,
          roster: _leaderContext().roster,
        ),
      );
      expect(find.text('11 members'), findsOneWidget);
    });

    testWidgets('Disciple: the group card with Leader and Discipler', (
      tester,
    ) async {
      await pumpHome(tester, ministryContext: _discipleContext());
      expect(find.text('Ana Leader'), findsOneWidget);
      expect(find.text('Your Leader'), findsOneWidget);
      expect(find.text('Ben Discipler'), findsOneWidget);
      expect(find.text('Your Discipler'), findsOneWidget);
      expect(find.text("You're a Disciple"), findsOneWidget);
    });

    testWidgets('Disciple without a Discipler: "not paired yet"', (
      tester,
    ) async {
      await pumpHome(tester, ministryContext: _discipleContext(paired: false));
      expect(find.text('Not paired with a Discipler yet'), findsOneWidget);
    });

    testWidgets('added but not set up: which group, and who sets it up', (
      tester,
    ) async {
      await pumpHome(tester, ministryContext: _needsSetupContext());
      expect(find.text("You're in Young Adults A"), findsOneWidget);
      expect(find.text('Role not set up yet'), findsOneWidget);
      expect(find.text('Not in a D Group yet'), findsNothing);
    });
  });

  group('AppTextLink on detail', () {
    testWidgets('Change Leader is a text link', (tester) async {
      await pumpDetail(tester, roles: const {ChurchRole.coordinator});
      expect(find.widgetWithText(AppTextLink, 'Change Leader'), findsOneWidget);
    });
  });
}
