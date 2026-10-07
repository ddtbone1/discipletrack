import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../discipleship/domain/journey.dart';
import '../application/curriculum_providers.dart';
import '../domain/lesson_content.dart';
import 'lesson_index_page.dart';

/// The Disciple's lessons on Home, as cover cards to swipe through,
/// starting on the current one. A lesson they have reached opens on tap;
/// the rest show a lock. Whether a lesson opens is the database's answer
/// (`list_lesson_access()`, ADR-019); the journey only labels the cards.
class LessonCarousel extends ConsumerStatefulWidget {
  const LessonCarousel({required this.journey, super.key});

  /// The reader's own journey, which labels the cards and picks the first
  /// one; null for a Discipler without a journey, who sees the ten lessons
  /// from Lesson 1, all open (ADR-019 decision 16).
  final DiscipleJourney? journey;

  @override
  ConsumerState<LessonCarousel> createState() => _LessonCarouselState();
}

class _LessonCarouselState extends ConsumerState<LessonCarousel> {
  late final PageController _controller = PageController(
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
    final open = {
      for (final a in access)
        if (a.isOpen) a.lessonId,
    };
    final covers = ref.watch(lessonCoversProvider).value ?? const {};
    final journey = widget.journey;
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
              onTap: isOpen ? () => context.push(Routes.lessonFor(c.id)) : null,
            ),
          );
        },
      ),
    );
  }
}
