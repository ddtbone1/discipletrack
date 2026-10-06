import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/journey.dart';
import '../domain/meeting_history_entry.dart';
import 'current_lesson_card.dart';

/// Asks before marking [lesson] completed (ADR-015), showing what was
/// recorded and what changes: the meetings on the lesson, the next lesson
/// becoming current for everyone, and how long it can be undone. Resolves
/// true only on "Mark completed".
Future<bool> showLessonCompleteDialog(
  BuildContext context, {
  required String firstName,
  required JourneyLesson lesson,
  required int lessonsTotal,
  required List<MeetingHistoryEntry> meetings,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialog) => _LessonCompleteDialog(
      firstName: firstName,
      lesson: lesson,
      lessonsTotal: lessonsTotal,
      meetings: meetings,
    ),
  );
  return result ?? false;
}

class _LessonCompleteDialog extends StatelessWidget {
  const _LessonCompleteDialog({
    required this.firstName,
    required this.lesson,
    required this.lessonsTotal,
    required this.meetings,
  });

  final String firstName;
  final JourneyLesson lesson;
  final int lessonsTotal;
  final List<MeetingHistoryEntry> meetings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final hasNext = lesson.number < lessonsTotal;
    final next = lesson.number + 1;

    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  size: 32,
                  color: p.onBrand,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mark Lesson ${lesson.number} completed?',
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$firstName · ${lesson.countLine}',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: p.muted),
            ),
            if (meetings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(child: OutcomePills(meetings: meetings)),
            ],
            const SizedBox(height: AppSpacing.md),
            // What changes, as a step from this lesson to the next.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: neutralFill(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: hasNext
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: 'Lesson $next becomes the current lesson',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppPill(
                                tone: PillTone.brand,
                                icon: Icons.check_rounded,
                                label: 'Lesson ${lesson.number}',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: p.muted,
                                ),
                              ),
                              AppPill(
                                icon: Icons.play_arrow_rounded,
                                label: 'Lesson $next',
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Last lesson',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.undo_rounded, size: 18, color: p.muted),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    "Undo until the next lesson's first meeting.",
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Mark completed',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
