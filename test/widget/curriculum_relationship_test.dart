// Slice 8 (ADR-023): curriculum access follows the relationship. My Journey
// is the reader's own journey, shown as a Disciple sees it; the Coordinator's
// Curriculum and a Disciple's context show what the database returned; the
// device copy is read through the context a lesson is opened in.
import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:discipletrack/features/curriculum/presentation/lesson_carousel.dart';
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

void main() {
  group('the reader', () {
    testWidgets('in the reader\'s own view shows the Disciple view, without '
        'answers and without a Show answers switch, even when the database '
        'returned both tiers (a Coordinator\'s own journey)', (tester) async {
      final repo = FakeCurriculumRepository(
        access: sampleLessonAccess(open: 5, discipler: true),
        content: {sampleLessonId(5): sampleLessonContent(5, discipler: true)},
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(5)),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        curriculumRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('Section A · Opening section'), findsOne);
      expect(find.text('For the Discipler', skipOffstage: false), findsNothing);
      expect(find.text('Show answers', skipOffstage: false), findsNothing);
      expect(find.byType(Switch, skipOffstage: false), findsNothing);
    });

    testWidgets('opened from the Coordinator\'s Curriculum shows both tiers', (
      tester,
    ) async {
      final repo = FakeCurriculumRepository(
        access: sampleLessonAccess(open: 5, discipler: true),
        content: {sampleLessonId(5): sampleLessonContent(5, discipler: true)},
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(5), oversight: true),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        curriculumRepo: repo,
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('For the Discipler'), 200);
      expect(find.text('For the Discipler'), findsOne);
      expect(find.byType(Switch, skipOffstage: false), findsNothing);
    });

    testWidgets('offline, a lesson the reader may read only in a Disciple\'s '
        'context does not open in their own view', (tester) async {
      final copy = ReadableContent(
        userId: sampleUserId,
        savedAt: DateTime.utc(2026, 10, 8),
        // Own journey: nothing reached.
        lessons: sampleLessonAccess(open: 0),
        contexts: {'cm-d': sampleLessonAccess(open: 5, discipler: true)},
        blocks: sampleLessonContent(5, discipler: true).blocks,
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(5)),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(offline: true),
        curriculumCache: MemoryCurriculumCacheStore(copy),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section A · Opening section'), findsNothing);
      expect(find.text('For the Discipler', skipOffstage: false), findsNothing);
    });

    testWidgets('offline, the same lesson opens in that Disciple\'s context '
        'with the Discipler tier', (tester) async {
      final copy = ReadableContent(
        userId: sampleUserId,
        savedAt: DateTime.utc(2026, 10, 8),
        lessons: sampleLessonAccess(open: 0),
        contexts: {'cm-d': sampleLessonAccess(open: 5, discipler: true)},
        blocks: sampleLessonContent(5, discipler: true).blocks,
      );
      await pumpPage(
        tester,
        LessonReaderPage(lessonId: sampleLessonId(5), forMembershipId: 'cm-d'),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(offline: true),
        curriculumCache: MemoryCurriculumCacheStore(copy),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('For the Discipler'), 200);
      expect(find.text('For the Discipler'), findsOne);
    });
  });

  group('My Journey never opens a lesson ahead of the journey', () {
    testWidgets('the carousel opens only reached lessons, even when the '
        'database would open all ten (a Coordinator who is a Disciple)', (
      tester,
    ) async {
      await pumpPage(
        tester,
        LessonCarousel(journey: sampleJourney(total: 10, completed: 2)),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 10, discipler: true),
        ),
      );
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<LessonCoverCard>(
            find.byType(LessonCoverCard, skipOffstage: false),
          )
          .toList();
      // The carousel builds the cards around the current one (Lesson 3).
      expect(cards.map((c) => c.lesson.number), containsAll([3, 4]));
      for (final c in cards) {
        expect(
          c.onTap != null,
          c.lesson.number <= 3,
          reason: 'Lesson ${c.lesson.number}: open only when reached',
        );
      }
    });

    testWidgets('a Discipler\'s own Lessons carousel starts on Lesson 1 and '
        'opens every lesson the database opens (ADR-024)', (tester) async {
      await pumpPage(
        tester,
        const LessonCarousel.book(),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 10, discipler: true),
        ),
      );
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<LessonCoverCard>(
            find.byType(LessonCoverCard, skipOffstage: false),
          )
          .toList();
      expect(cards.first.lesson.number, 1);
      expect(cards.map((c) => c.lesson.number), containsAll([1, 2]));
      expect(cards.every((c) => c.onTap != null), isTrue);
      expect(find.textContaining('Now'), findsNothing, reason: 'no journey');
    });

    testWidgets('a journey and the book on one page each open on their own '
        'start: neither restores the other\'s page', (tester) async {
      await pumpPage(
        tester,
        Column(
          children: [
            LessonCarousel(journey: sampleJourney(total: 10, completed: 2)),
            const LessonCarousel.book(),
          ],
        ),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 10, discipler: true),
        ),
      );
      await tester.pumpAndSettle();
      final views = tester.widgetList<PageView>(find.byType(PageView));
      expect(views, hasLength(2));
      // A kept page is shared through PageStorage by both carousels.
      expect(views.every((v) => v.controller?.keepPage == false), isTrue);
      expect(find.text('Lesson 3 · Now'), findsOne);
    });

    testWidgets('the same whole-book list is "Lessons" for a Discipler and '
        'keeps "Curriculum" for the Coordinator', (tester) async {
      await pumpPage(
        tester,
        const LessonIndexPage(oversight: true),
        membership: _active,
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 10, discipler: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lessons'), findsWidgets);
      expect(find.text('Curriculum'), findsNothing);
    });

    testWidgets('the Curriculum list opens what the database allows', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const LessonIndexPage(oversight: true),
        membership: _active,
        roles: const {ChurchRole.coordinator},
        curriculumRepo: FakeCurriculumRepository(
          access: sampleLessonAccess(open: 10, discipler: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Curriculum'), findsWidgets);
      final cards = tester.widgetList<LessonCoverCard>(
        find.byType(LessonCoverCard, skipOffstage: false),
      );
      expect(cards.where((c) => c.onTap != null), hasLength(10));
    });
  });
}
