import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../application/curriculum_providers.dart';
import '../data/curriculum_repository.dart';
import '../domain/lesson_content.dart';

/// The ten lessons as cards over the book's cover photos (ADR-019).
///
/// Which lessons open is the database's answer, in the context of
/// [forMembershipId] or of the reader: a Disciple opens completed lessons
/// and the current one, a Discipler opens all. The rest show a lock.
class LessonIndexPage extends ConsumerWidget {
  const LessonIndexPage({this.forMembershipId, super.key});

  final String? forMembershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonAccessProvider(forMembershipId));
    final covers = ref.watch(lessonCoversProvider).value ?? const {};

    return AppScaffold(
      title: 'Lessons',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          lessons.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => e is CurriculumFailure && e.isRefused
                ? const EmptyState.restricted(
                    title: "These lessons aren't available",
                    message: 'Lessons open as the journey reaches them.',
                  )
                : SizedBox(
                    height: 320,
                    child: ErrorState.load(
                      subject: 'the lessons',
                      error: e,
                      onRetry: () =>
                          ref.invalidate(lessonAccessProvider(forMembershipId)),
                    ),
                  ),
            data: (all) => all.isEmpty
                ? const EmptyState(
                    illustration: Illustration.reading,
                    title: 'No lessons yet',
                    message: "Your church's curriculum hasn't been set up yet.",
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final l in all) ...[
                        LessonCoverCard(
                          lesson: l,
                          cover: covers[l.lessonId],
                          onTap: l.isOpen
                              ? () => context.push(
                                  Routes.lessonFor(
                                    l.lessonId,
                                    forMembershipId: forMembershipId,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// One lesson over its cover photo: number and title, and a lock when it
/// is not open.
class LessonCoverCard extends StatelessWidget {
  const LessonCoverCard({
    required this.lesson,
    this.cover,
    this.onTap,
    this.height = 132,
    this.caption,
    super.key,
  });

  final LessonAccess lesson;
  final Uint8List? cover;
  final VoidCallback? onTap;
  final double height;

  /// The line above the title; "Lesson n" when not given, none when empty.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final open = lesson.isOpen;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: open,
      label:
          '${caption == '' ? '' : '${caption ?? 'Lesson ${lesson.number}'}, '}'
          '${lesson.title}${open ? '' : ', locked'}',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null)
                  Image.memory(
                    cover!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    color: open ? null : const Color(0x8C000000),
                    colorBlendMode: open ? null : BlendMode.darken,
                  ),
                // Keeps the words readable on any photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.2, 1],
                      colors: [Color(0x00000000), Color(0xE0000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (caption != '')
                              Text(
                                caption ?? 'Lesson ${lesson.number}',
                                style: text.labelMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              lesson.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        open
                            ? Icons.arrow_forward_rounded
                            : Icons.lock_outline_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
