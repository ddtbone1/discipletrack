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

  final DiscipleJourney journey;

  @override
  ConsumerState<LessonCarousel> createState() => _LessonCarouselState();
}

class _LessonCarouselState extends ConsumerState<LessonCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: 0.86,
    initialPage: _startIndex,
  );

  int get _startIndex {
    final lessons = widget.journey.lessons;
    final current = widget.journey.currentLesson;
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
    final lessons = widget.journey.lessons;
    final open = {
      for (final a in ref.watch(lessonAccessProvider(null)).value ?? const [])
        if (a.isOpen) a.lessonId,
    };
    final covers = ref.watch(lessonCoversProvider).value ?? const {};
    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: lessons.length,
        itemBuilder: (context, i) {
          final l = lessons[i];
          final isOpen = open.contains(l.lessonId);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: LessonCoverCard(
              height: 150,
              caption: switch (l.state) {
                _ when l.isCurrent => 'Lesson ${l.number} · Now',
                LessonState.completed => 'Lesson ${l.number} · Done',
                _ => 'Lesson ${l.number}',
              },
              lesson: LessonAccess(
                lessonId: l.lessonId,
                number: l.number,
                title: l.title,
                discipleTier: isOpen,
                disciplerTier: false,
              ),
              cover: covers[l.lessonId],
              onTap: isOpen
                  ? () => context.push(Routes.lessonFor(l.lessonId))
                  : null,
            ),
          );
        },
      ),
    );
  }
}
