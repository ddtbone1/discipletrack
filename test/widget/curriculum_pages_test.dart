import 'package:discipletrack/features/curriculum/domain/workbook.dart';
import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:discipletrack/features/curriculum/presentation/lesson_index_page.dart';
import 'package:discipletrack/features/curriculum/presentation/lesson_reader_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final _active = sampleMembership(
  MembershipStatus.active,
  joinedAt: DateTime.utc(2026, 3, 1),
  onboardingCompletedAt: DateTime.utc(2026, 3, 1),
);

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  group('lesson list', () {
    testWidgets('ten cover cards; open lessons lead on, the rest are locked', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const LessonIndexPage(),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 2),
        ),
      );
      await _settle(tester);

      final rows = tester
          .widgetList<LessonCoverCard>(
            find.byType(LessonCoverCard, skipOffstage: false),
          )
          .toList();
      expect(rows, hasLength(10));
      expect(rows.where((r) => r.onTap != null), hasLength(2));
      expect(rows[2].onTap, isNull);
      expect(
        find.byIcon(Icons.lock_outline_rounded, skipOffstage: false),
        findsNWidgets(8),
      );
    });

    testWidgets('without a journey nothing is open', (tester) async {
      await pumpPage(
        tester,
        const LessonIndexPage(),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(access: sampleLessonAccess()),
      );
      await _settle(tester);

      final rows = tester.widgetList<LessonCoverCard>(
        find.byType(LessonCoverCard, skipOffstage: false),
      );
      expect(rows.every((r) => r.onTap == null), isTrue);
    });
  });

  group('lesson reader', () {
    testWidgets('a Disciple reads sections and scriptures, never the '
        'Discipler tier', (tester) async {
      final repo = FakeCurriculumRepository(
        access: sampleLessonAccess(open: 1),
        content: {sampleLessonId(1): sampleLessonContent(1)},
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(1)),
        membership: _active,
        curriculumRepo: repo,
      );
      await _settle(tester);

      expect(find.text('Salvation'), findsWidgets);
      expect(find.text('What this lesson covers'), findsOne);
      expect(find.text('Section A · Opening section'), findsOne);
      expect(find.text('John 3:16'), findsOne);
      expect(find.textContaining('printed Journey book'), findsOne);
      expect(find.text('For the Discipler'), findsNothing);
      expect(repo.contentReads.single.forMembershipId, isNull);
    });

    testWidgets('the assigned Discipler also sees the Discipler tier', (
      tester,
    ) async {
      final repo = FakeCurriculumRepository(
        access: sampleLessonAccess(open: 5, discipler: true),
        content: {sampleLessonId(5): sampleLessonContent(5, discipler: true)},
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(5), forMembershipId: 'cm-d'),
        membership: _active,
        curriculumRepo: repo,
      );
      await _settle(tester);

      await tester.scrollUntilVisible(find.text('For the Discipler'), 200);
      expect(find.text('For the Discipler'), findsOne);
      expect(
        find.textContaining('Training Module 1', skipOffstage: false),
        findsOne,
      );
      expect(repo.contentReads.single.forMembershipId, 'cm-d');
    });

    testWidgets('a lesson the database refuses shows the restricted state', (
      tester,
    ) async {
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(6)),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 1),
        ),
      );
      // No settle: a refusal is final and is not retried.
      await tester.pump();
      await tester.pump();

      expect(find.text("This lesson isn't open"), findsOne);
      expect(find.text('John 3:16'), findsNothing);
    });

    testWidgets('offline, a synced lesson is read from the device copy', (
      tester,
    ) async {
      final copy = ReadableContent(
        userId: sampleUserId,
        savedAt: DateTime.utc(2026, 10, 6),
        lessons: sampleLessonAccess(open: 1),
        blocks: sampleLessonContent(1).blocks,
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(1)),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(offline: true),
        curriculumCache: MemoryCurriculumCacheStore(copy),
      );
      await _settle(tester);

      expect(find.text('Section A · Opening section'), findsOne);
      expect(find.text('John 3:16'), findsOne);
    });

    testWidgets('offline without a copy explains what to do', (tester) async {
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(1)),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(offline: true),
        curriculumCache: MemoryCurriculumCacheStore(),
      );
      await _settle(tester);

      expect(find.text("You're offline"), findsOne);
      expect(find.text('John 3:16'), findsNothing);
    });
  });

  testWidgets('a block type this app does not know renders nothing', (
    tester,
  ) async {
    final lesson = LessonContent(
      lessonId: sampleLessonId(1),
      blocks: [
        ...sampleLessonContent(1).blocks,
        ContentBlock.fromMap({
          'block_id': 'b-x',
          'ordinal': 9,
          'section_label': 'A',
          'block_type': 'SOMETHING_NEW',
          'tier': 'DISCIPLE',
          'body': {'text': 'Should not appear'},
        }, lessonId: sampleLessonId(1)),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LessonBody(lesson: lesson)),
        ),
      ),
    );

    expect(find.text('Should not appear'), findsNothing);
    expect(find.text('John 3:16'), findsOne);
  });
  group('full lesson', () {
    LessonContent lesson({required bool withAnswers}) => LessonContent(
      lessonId: sampleLessonId(1),
      blocks: [
        for (final (i, r) in <Map<String, dynamic>>[
          {
            'block_type': 'SECTION_HEADING',
            'section_label': 'A',
            'body': {'title': 'Opening'},
          },
          {
            'block_type': 'POINT',
            'section_label': 'A',
            'body': {
              'reference': 'John 1:1',
              'text': 'In the [_] was the Word.',
              'blanks': 1,
            },
            'answers': withAnswers ? ['beginning'] : null,
          },
          {
            'block_type': 'VERSE_WRITING',
            'body': {
              'reference': 'John 11:35',
              'instruction': 'Write John 11:35 below.',
              'lines': 2,
              'blanks': 1,
            },
            'answers': withAnswers ? ['Jesus wept.'] : null,
          },
        ].indexed)
          ContentBlock.fromMap({
            'block_id': 'f$i',
            'ordinal': i + 1,
            'tier': 'DISCIPLE',
            ...r,
          }, lessonId: sampleLessonId(1)),
      ],
    );

    Future<void> show(WidgetTester tester, LessonContent l) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: LessonBody(lesson: l)),
            ),
          ),
        );

    testWidgets('the Disciple sees the wording with empty blanks', (
      tester,
    ) async {
      await show(tester, lesson(withAnswers: false));
      expect(find.text('Section A'.toUpperCase()), findsOneWidget);
      expect(find.text('John 1:1'), findsOneWidget);
      expect(find.textContaining('In the ', findRichText: true), findsOne);
      expect(
        find.textContaining('beginning', findRichText: true),
        findsNothing,
      );
      expect(find.text('Jesus wept.'), findsNothing);
      expect(find.textContaining('printed Journey book'), findsNothing);
    });

    testWidgets('the Discipler sees each answer in its blank', (tester) async {
      await show(tester, lesson(withAnswers: true));
      expect(
        find.textContaining('beginning', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Jesus wept.'), findsOneWidget);
    });

    testWidgets('with a workbook the Disciple writes in the blanks and the '
        'verse, and it is saved; a reopened lesson shows it again', (
      tester,
    ) async {
      Map<String, Map<String, String>>? saved;
      final workbook = Workbook(
        entries: const {},
        onSave: (e) async => saved = e,
        saveDelay: Duration.zero,
      );
      Future<void> showWith(Workbook wb) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonBody(
                lesson: lesson(withAnswers: false),
                workbook: wb,
              ),
            ),
          ),
        ),
      );
      await showWith(workbook);

      expect(find.textContaining('Saved on this phone only'), findsOne);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.first, 'beginning');
      await tester.enterText(fields.last, 'Jesus wept.');
      await tester.pump();
      expect(saved, {
        'f1': {'b0': 'beginning'},
        'f2': {'v': 'Jesus wept.'},
      });

      await showWith(Workbook(entries: saved!, onSave: (_) async {}));
      expect(find.text('beginning'), findsOneWidget);
    });

    testWidgets('without a workbook nothing is editable', (tester) async {
      await show(tester, lesson(withAnswers: false));
      expect(find.byType(TextField), findsNothing);
    });
  });
}
