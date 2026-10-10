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
import '../../discipleship/application/discipleship_providers.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/curriculum_providers.dart';
import '../data/curriculum_repository.dart';
import '../domain/lesson_content.dart';

/// The ten lessons as cards over the book's cover photos (ADR-019).
///
/// Which lessons open is the database's answer, in the context of
/// [forMembershipId] or of the reader (ADR-023): in their own context
/// everyone opens their own journey (completed lessons and the current one);
/// in a currently assigned Disciple's context a Discipler opens all ten; the
/// Coordinator opens all. The rest show a lock.
///
/// [oversight] is the whole book (Routes.curriculum): the Coordinator's
/// Curriculum, and a Discipler's own Lessons (ADR-024). It is kept
/// apart from My Journey: its lessons open with both tiers.
class LessonIndexPage extends ConsumerWidget {
  const LessonIndexPage({
    this.forMembershipId,
    this.oversight = false,
    super.key,
  });

  final String? forMembershipId;
  final bool oversight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonAccessProvider(forMembershipId));
    // The reader's own view is their own journey: nothing ahead of it opens,
    // whatever else the reader may read elsewhere (ADR-023 decision 10).
    final reached = forMembershipId == null && !oversight
        ? ref.watch(myJourneyProvider).value?.reachedLessonIds
        : null;
    LessonAccess shown(LessonAccess l) =>
        reached == null || reached.contains(l.lessonId) || !l.isOpen
        ? l
        : LessonAccess(
            lessonId: l.lessonId,
            number: l.number,
            title: l.title,
            discipleTier: false,
            disciplerTier: false,
          );
    final covers = ref.watch(lessonCoversProvider).value ?? const {};

    return AppScaffold(
      // "Curriculum" is the Coordinator's word for the whole book; a
      // Discipler or Leader reading the same view calls it Lessons (user,
      // Phase 4 review).
      title: oversight && ref.watch(isCoordinatorProvider)
          ? 'Curriculum'
          : 'Lessons',
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
                      for (final l in all.map(shown)) ...[
                        LessonCoverCard(
                          lesson: l,
                          cover: covers[l.lessonId],
                          onTap: l.isOpen
                              ? () => context.push(
                                  Routes.lessonFor(
                                    l.lessonId,
                                    forMembershipId: forMembershipId,
                                    oversight: oversight,
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
                  // The photo is quietened so the card reads as one calm
                  // surface (user, 2026-10-07): less colour, a little
                  // darker, darker still when locked.
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      _muted(open ? 0.85 : 0.55, saturation: 0.7),
                    ),
                    child: Image.memory(
                      cover!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                // A soft veil over the whole photo and a deep shade at the
                // foot, where the words sit.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.45, 1],
                      colors: [
                        Color(0x26000000),
                        Color(0x4D000000),
                        Color(0xEB000000),
                      ],
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

/// A colour matrix that scales brightness and saturation.
List<double> _muted(double brightness, {required double saturation}) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final s = saturation;
  final k = brightness;
  return [
    k * (r + (1 - r) * s), k * (g - g * s), k * (b - b * s), 0, 0, //
    k * (r - r * s), k * (g + (1 - g) * s), k * (b - b * s), 0, 0, //
    k * (r - r * s), k * (g - g * s), k * (b + (1 - b) * s), 0, 0, //
    0, 0, 0, 1, 0,
  ];
}
