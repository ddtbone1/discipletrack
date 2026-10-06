import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../discipleship/domain/journey.dart';
import '../application/curriculum_providers.dart';
import '../domain/lesson_content.dart';
import 'lesson_index_page.dart';

/// The one way into the lessons from a journey page: the current lesson's
/// cover, opening the list of all ten in the journey's context.
class LessonsNavCard extends ConsumerWidget {
  const LessonsNavCard({
    required this.journey,
    this.forMembershipId,
    super.key,
  });

  final DiscipleJourney journey;
  final String? forMembershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = journey.currentLesson ?? journey.lessons.lastOrNull;
    if (current == null) return const SizedBox.shrink();
    final covers = ref.watch(lessonCoversProvider).value ?? const {};
    return LessonCoverCard(
      height: 112,
      caption: '',
      lesson: LessonAccess(
        lessonId: current.lessonId,
        number: current.number,
        title: 'Lessons',
        discipleTier: true,
        disciplerTier: false,
      ),
      cover: covers[current.lessonId],
      onTap: () =>
          context.push(Routes.lessonsFor(forMembershipId: forMembershipId)),
    );
  }
}
