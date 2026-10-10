import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../discipleship/domain/journey.dart';
import '../application/curriculum_providers.dart';
import '../domain/lesson_content.dart';
import 'lesson_index_page.dart';

/// Lessons on Home, as cover cards to swipe through. Whether a lesson opens
/// is the database's answer (`list_lesson_access()`); the carousel only
/// presents it.
///
/// - [LessonCarousel.new]: the Disciple's own journey, starting on the
///   current lesson. A lesson they have reached opens; the rest show a
///   lock. My Journey never opens a lesson ahead of the person's own
///   progression, even for someone who may read the whole book elsewhere
///   (ADR-023 decision 10).
/// - [LessonCarousel.book]: a Discipler's own complete lessons, every
///   Leader included (ADR-024), from Lesson 1, each opening in the
///   Curriculum view with the Discipler's answers. Kept apart from the
///   journey, so a Discipler who is also a Disciple keeps both.
class LessonCarousel extends ConsumerStatefulWidget {
  const LessonCarousel({required DiscipleJourney this.journey, super.key});

  const LessonCarousel.book({super.key}) : journey = null;

  /// The reader's own journey, which labels the cards and picks the first;
  /// null for the Discipler's book.
  final DiscipleJourney? journey;

  @override
  ConsumerState<LessonCarousel> createState() => _LessonCarouselState();
}

class _LessonCarouselState extends ConsumerState<LessonCarousel> {
  // keepPage false: Home can hold two carousels (a journey and the book),
  // and kept pages would share one PageStorage slot, so one carousel would
  // open on the other's page instead of its own start.
  late final PageController _controller = PageController(
    keepPage: false,
    viewportFraction: 0.86,
    initialPage: _startIndex,
  );

  int get _startIndex {
    final journey = widget.journey;
    if (journey == null) return 0;
    final lessons = journey.lessons;
    final current = journey.currentLesson;
    if (current == null) return lessons.isEmpty ? 0 : lessons.length - 1;
    final i = lessons.indexWhere((l) => l.lessonId == current.lessonId);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access =
        ref.watch(lessonAccessProvider(null)).value ?? const <LessonAccess>[];
    final journey = widget.journey;
    final reached = journey?.reachedLessonIds;
    final open = {
      for (final a in access)
        if (a.isOpen && (reached == null || reached.contains(a.lessonId)))
          a.lessonId,
    };
    final covers = ref.watch(lessonCoversProvider).value ?? const {};
    // One card per lesson: from the journey when there is one, else from
    // the lesson list.
    final cards = journey != null
        ? [
            for (final l in journey.lessons)
              (
                id: l.lessonId,
                number: l.number,
                title: l.title,
                caption: switch (l.state) {
                  _ when l.isCurrent => 'Lesson ${l.number} · Now',
                  LessonState.completed => 'Lesson ${l.number} · Done',
                  _ => 'Lesson ${l.number}',
                },
              ),
          ]
        : [
            for (final a in access)
              (
                id: a.lessonId,
                number: a.number,
                title: a.title,
                caption: 'Lesson ${a.number}',
              ),
          ];
    if (cards.isEmpty) return const SizedBox(height: 150);
    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final c = cards[i];
          final isOpen = open.contains(c.id);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: LessonCoverCard(
              height: 150,
              caption: c.caption,
              lesson: LessonAccess(
                lessonId: c.id,
                number: c.number,
                title: c.title,
                discipleTier: isOpen,
                disciplerTier: false,
              ),
              cover: covers[c.id],
              onTap: isOpen
                  ? () => context.push(
                      Routes.lessonFor(c.id, oversight: journey == null),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
