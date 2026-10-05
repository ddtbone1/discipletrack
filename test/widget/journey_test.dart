import 'package:discipletrack/features/discipleship/domain/disciple_progress_summary.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/presentation/journey_page.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/ministry/presentation/my_group_page.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:discipletrack/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final _active = sampleMembership(
  MembershipStatus.active,
  joinedAt: DateTime.utc(2026, 3, 1),
  onboardingCompletedAt: DateTime.utc(2026, 3, 1),
);
final _myId = _active.id;

RosterEntry _row(
  String id,
  String name,
  DGroupResponsibility r, {
  bool me = false,
  bool myDisciple = false,
  bool myDiscipler = false,
}) => RosterEntry(
  dGroupMembershipId: 'dgm-$id-${r.name}',
  churchMembershipId: id == 'me' ? _myId : 'cm-$id',
  fullName: name,
  responsibility: r,
  isMe: me,
  isMyDisciple: myDisciple,
  isMyDiscipler: myDiscipler,
);

/// Builds the caller's context from what they hold. The combined Disciple
/// and Discipler states are constructed here because the database refuses
/// them until Slice 6.
MinistryContext _context({
  bool disciple = false,
  bool discipler = false,
  bool leader = false,
  List<String> disciples = const [],
  bool paired = true,
}) => MinistryContext(
  dGroupId: 'g1',
  dGroupName: 'Young Adults A',
  roster: [
    if (leader)
      _row('me', 'James Mercado', DGroupResponsibility.leader, me: true),
    if (discipler)
      _row('me', 'James Mercado', DGroupResponsibility.discipler, me: true),
    if (disciple)
      _row('me', 'James Mercado', DGroupResponsibility.disciple, me: true),
    if (disciple && paired)
      _row(
        'mark',
        'Mark Reyes',
        DGroupResponsibility.discipler,
        myDiscipler: true,
      ),
    for (final name in disciples)
      _row(
        name.toLowerCase().split(' ').first,
        name,
        DGroupResponsibility.disciple,
        myDisciple: true,
      ),
  ],
);

DiscipleProgressSummary _summary(String name) => DiscipleProgressSummary(
  membershipId: 'cm-${name.toLowerCase().split(' ').first}',
  fullName: name,
  lessonsTotal: 12,
  lessonsCompleted: 2,
  creditedCount: 1,
  recordedAbsences: 0,
  currentLessonNumber: 3,
  currentState: LessonState.inProgress,
);

FakeDiscipleshipRepository _repo({
  LessonState state = LessonState.inProgress,
  List<String> disciples = const [],
}) => FakeDiscipleshipRepository()
  ..journeys = {_myId: sampleJourney(currentState: state)}
  ..disciples = [for (final d in disciples) _summary(d)]
  ..summaries = {
    _myId: MeetingSummary(
      meetingsAttended: 3,
      recordedAbsences: 1,
      excused: 0,
      consecutiveRecordedAbsences: 1,
      lastRecordedMeetingAt: DateTime.utc(2026, 9, 28, 12),
    ),
  };

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  MinistryContext? ministry,
  FakeDiscipleshipRepository repo, {
  Set<ChurchRole> roles = const {},
}) async {
  await pumpPage(
    tester,
    page,
    membership: _active,
    roles: roles,
    ministryRepo: FakeMinistryRepository()..ministryContext = ministry,
    discipleshipRepo: repo,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Journey views', () {
    testWidgets('a Disciple sees My Journey directly, with no tab bar', (
      tester,
    ) async {
      await _pump(
        tester,
        const JourneyPage(),
        _context(disciple: true),
        _repo(),
      );
      expect(find.byType(TabBar), findsNothing);
      // The current lesson is the first thing on the page.
      expect(find.text('CURRENT LESSON'), findsOneWidget);
    });

    testWidgets('a Discipler with no journey of their own sees My Disciples '
        'directly', (tester) async {
      await _pump(
        tester,
        const JourneyPage(),
        _context(discipler: true, disciples: ['Ana Lim']),
        _repo(disciples: ['Ana Lim']),
      );
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Ana Lim'), findsOneWidget);
    });

    testWidgets('both relationships give two tabs, My Journey first; the '
        'query selects My Disciples', (tester) async {
      final ctx = _context(
        disciple: true,
        discipler: true,
        disciples: ['Ana Lim'],
      );
      await _pump(
        tester,
        const JourneyPage(),
        ctx,
        _repo(disciples: ['Ana Lim']),
      );
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('My Journey'), findsOneWidget);
      expect(find.text('My Disciples'), findsOneWidget);
      expect(find.text('Ana Lim'), findsNothing);

      await tester.tap(find.text('My Disciples'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Lim'), findsOneWidget);

      await _pump(
        tester,
        const JourneyPage(initialView: 'disciples'),
        ctx,
        _repo(disciples: ['Ana Lim']),
      );
      expect(find.text('Ana Lim'), findsOneWidget);
    });

    testWidgets('a Disciple who is appointed with nobody paired gets a note, '
        'not an empty tab', (tester) async {
      await _pump(
        tester,
        const JourneyPage(),
        _context(disciple: true, discipler: true),
        _repo(),
      );
      expect(find.byType(TabBar), findsNothing);
      expect(find.textContaining("You're also a Discipler"), findsOneWidget);
    });
  });

  group('My Journey', () {
    testWidgets('shows factual progress, the own wording, the timeline and '
        'that the page is read-only', (tester) async {
      await _pump(
        tester,
        const JourneyPage(),
        _context(disciple: true),
        _repo(),
      );
      expect(find.text('Lesson 4'), findsOneWidget);
      expect(find.text('Discipler: Mark Reyes'), findsOneWidget);
      // Overall facts are pills by the meetings; the last recorded meeting
      // stands out in the current lesson card.
      expect(find.text('3 meetings attended'), findsOneWidget);
      expect(find.text('1 recorded absence'), findsOneWidget);
      expect(find.text('Last recorded meeting Sep 28'), findsOneWidget);
      expect(find.text('In progress since Sep 3'), findsOneWidget);
      expect(
        find.text(
          'This page is read-only. Your Discipler records your meetings.',
        ),
        findsOneWidget,
      );
      // Every lesson sits in a collapsed list below.
      expect(find.text('Opens after Lesson 4 is completed.'), findsNothing);
      await tester.ensureVisible(find.text('All lessons'));
      await tester.tap(find.text('All lessons'));
      await tester.pumpAndSettle();
      expect(find.text('Opens after Lesson 5 is completed.'), findsOneWidget);
      expect(find.textContaining('No meetings recorded yet.'), findsOneWidget);
      expect(find.text('Record a meeting'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('an unpaired Disciple is told progress starts once paired', (
      tester,
    ) async {
      await _pump(
        tester,
        const JourneyPage(),
        _context(disciple: true, paired: false),
        _repo(),
      );
      expect(
        find.textContaining("You're not paired with a Discipler yet"),
        findsOneWidget,
      );
    });
  });

  group('Home', () {
    testWidgets('a Disciple sees their journey block', (tester) async {
      await _pump(tester, const HomePage(), _context(disciple: true), _repo());
      expect(find.text('YOUR JOURNEY'), findsOneWidget);
      expect(find.text('Lesson 4 · 2 meetings recorded'), findsOneWidget);
      // Once, on the D Group card; not repeated in the journey block.
      expect(find.text('Mark Reyes'), findsOneWidget);
      expect(find.text('Your Discipler'), findsOneWidget);
      expect(find.text('YOUR DISCIPLESHIPS'), findsNothing);
    });

    testWidgets('a Discipler sees their discipleships with Record a meeting', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomePage(),
        _context(discipler: true, disciples: ['Ana Lim', 'Ben Cruz']),
        _repo(disciples: ['Ana Lim', 'Ben Cruz']),
      );
      expect(find.text('YOUR DISCIPLESHIPS'), findsOneWidget);
      expect(find.text('Ana Lim'), findsOneWidget);
      expect(find.text('Record a meeting'), findsOneWidget);
      expect(find.text('YOUR JOURNEY'), findsNothing);
    });

    testWidgets('the Coordinator sees active discipleships as a figure', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomePage(),
        null,
        _repo()..progress = const ProgressSummary(activeDiscipleships: 5),
        roles: const {ChurchRole.coordinator},
      );
      expect(find.text('Active discipleships'), findsOneWidget);
      expect(find.bySemanticsLabel('Active discipleships: 5'), findsOneWidget);
    });
  });

  group('Profile', () {
    testWidgets('lists every responsibility, one journey summary and who the '
        'person disciples', (tester) async {
      await _pump(
        tester,
        const ProfilePage(),
        _context(
          disciple: true,
          discipler: true,
          disciples: ['Ana Lim', 'Ben Cruz'],
        ),
        _repo(),
      );
      expect(find.text('Disciple · Discipler'), findsOneWidget);
      expect(find.text('Ana Lim and Ben Cruz'), findsOneWidget);
      expect(
        find.text('Lesson 4 of 12 · 3 lessons completed · Lesson 4 current'),
        findsOneWidget,
      );
    });
  });

  group('My D Group', () {
    testWidgets('shows their own role, counts per role, and where each '
        'of their Disciples is', (tester) async {
      await _pump(
        tester,
        const MyGroupPage(),
        _context(discipler: true, disciples: ['Ana Lim', 'Ben Cruz']),
        _repo(disciples: ['Ana Lim', 'Ben Cruz']),
      );
      expect(find.text('Young Adults A'), findsOneWidget);
      expect(find.text('You · Discipler'), findsOneWidget);
      expect(find.text('Disciples'), findsOneWidget);
      // Each Disciple carries their lesson and last recorded meeting.
      expect(find.text('Lesson 3 of 12'), findsNWidgets(2));
      expect(find.text('No meeting recorded yet'), findsNWidgets(2));
    });
  });

  group('Disciple rows', () {
    testWidgets('use a stepper over the curriculum, described in words', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const HomePage(),
        _context(discipler: true, disciples: ['Ana Lim']),
        _repo(disciples: ['Ana Lim']),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Lesson 3 of 12. 2 lessons completed.')),
        findsOneWidget,
      );
      expect(find.text('Lesson 3 in progress'), findsOneWidget);
      handle.dispose();
    });
  });
}
