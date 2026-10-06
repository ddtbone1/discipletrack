import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/discipleship_providers.dart';
import '../domain/journey.dart';
import '../domain/journey_activity.dart';
import '../domain/meeting_history_entry.dart';
import 'activity_timeline.dart';
import 'current_lesson_card.dart';
import 'meeting_calendar.dart';

/// My Journey, a body of the Journey page: the person's own journey through
/// the lessons and the meetings recorded for each. Read-only; the Discipler
/// records meetings.
///
/// Read through the same per-person operations as anyone else's journey,
/// so the database decides what the person sees: their own rows only.
class MyJourneyBody extends ConsumerWidget {
  const MyJourneyBody({this.showAppointedNote = false, super.key});

  /// "You're also a Discipler", for a Disciple appointed with nobody paired
  /// yet, instead of an empty My Disciples tab.
  final bool showAppointedNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(myMembershipIdProvider);
    if (id == null) return const SizedBox.shrink();
    final journey = ref.watch(discipleJourneyProvider(id));
    final summary = ref.watch(meetingSummaryProvider(id)).value;
    final history = ref.watch(meetingHistoryProvider(id));
    final paired = ref.watch(myMinistryContextProvider).value?.myDiscipler;

    void retry() => ref
      ..invalidate(discipleJourneyProvider(id))
      ..invalidate(meetingSummaryProvider(id))
      ..invalidate(meetingHistoryProvider(id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAppointedNote) ...[
          Text(
            "You're also a Discipler. Disciples paired with you will appear "
            'here.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        journey.when(
          loading: () => const SizedBox(height: 320, child: LoadingState()),
          error: (e, _) => SizedBox(
            height: 320,
            child: ErrorState.load(
              subject: 'your progress',
              error: e,
              onRetry: retry,
            ),
          ),
          data: (j) => _Journey(
            journey: j,
            summary: summary,
            history: history,
            disciplerName: paired?.fullName,
            onRetryHistory: () => ref.invalidate(meetingHistoryProvider(id)),
          ),
        ),
      ],
    );
  }
}

class _Journey extends StatelessWidget {
  const _Journey({
    required this.journey,
    required this.summary,
    required this.history,
    required this.disciplerName,
    required this.onRetryHistory,
  });

  final DiscipleJourney journey;
  final MeetingSummary? summary;
  final AsyncValue<List<MeetingHistoryEntry>> history;

  /// Null when the person is not paired.
  final String? disciplerName;
  final VoidCallback onRetryHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (disciplerName == null) ...[
          const EmptyState(
            title: 'Not paired yet',
            message:
                "You're not paired with a Discipler yet. Progress starts once "
                'you are.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // Where the person is now comes first.
        CurrentLessonCard(
          journey: journey,
          history: history.value ?? const [],
          disciplerName: disciplerName,
          lastRecordedMeetingAt: summary?.lastRecordedMeetingAt,
          ownJourney: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This page is read-only. Your Discipler records your meetings.',
          style: context.captionStyle,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeading('Meetings'),
        history.when(
          loading: () => const SizedBox(height: 160, child: LoadingState()),
          error: (e, _) => SizedBox(
            height: 240,
            child: ErrorState.load(
              subject: 'your meetings',
              error: e,
              onRetry: onRetryHistory,
            ),
          ),
          data: (rows) => MeetingCalendar(
            entries: rows,
            emptyMessage:
                'No meetings recorded yet. When your Discipler records your '
                'first meeting, your progress starts here.',
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: AppSpacing.sm),
          MeetingFactPills(summary: summary!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AllLessonsList(journey: journey, ownJourney: true),
        if (kShowJourneyActivity) ...[
          const SizedBox(height: AppSpacing.lg),
          JourneyActivitySection(
            title: 'Journey activity',
            events: journeyActivity(
              journey,
              history.value ?? const [],
              ownJourney: true,
            ),
          ),
        ],
      ],
    );
  }
}
