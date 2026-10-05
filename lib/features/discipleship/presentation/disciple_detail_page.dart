import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/format/app_format.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/discipleship_providers.dart';
import '../data/discipleship_repository.dart';
import '../domain/journey.dart';
import '../domain/meeting_history_entry.dart';
import 'current_lesson_card.dart';
import 'meeting_calendar.dart';

/// One Disciple's journey and meeting history, for their Discipler, the
/// Leader of their group or the Coordinator.
///
/// Read-only apart from recording, which is offered only when the journey's
/// courtesy flag says the viewer may record. Who may open the page at all is
/// decided by the database for the pair (viewer, person); a refusal shows
/// the restricted state without confirming the person exists.
class DiscipleDetailPage extends ConsumerWidget {
  const DiscipleDetailPage({required this.membershipId, super.key});

  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(discipleContextProvider(membershipId));
    final journey = ref.watch(discipleJourneyProvider(membershipId));
    final history = ref.watch(meetingHistoryProvider(membershipId));

    void retry() {
      ref
        ..invalidate(discipleContextProvider(membershipId))
        ..invalidate(discipleJourneyProvider(membershipId))
        ..invalidate(meetingHistoryProvider(membershipId))
        ..invalidate(meetingSummaryProvider(membershipId));
    }

    final failure = person.error ?? journey.error;
    final Widget body;
    if (failure != null) {
      body = _isRefusal(failure)
          ? const EmptyState.restricted(
              message:
                  "Only this person's Discipler, Leader and the Coordinator "
                  'can open it.',
            )
          : SizedBox(
              height: 320,
              child: ErrorState.load(
                subject: 'this journey',
                error: failure,
                onRetry: retry,
              ),
            );
    } else if (!person.hasValue || !journey.hasValue) {
      body = const SizedBox(height: 320, child: LoadingState());
    } else {
      body = _Detail(
        person: person.requireValue,
        journey: journey.requireValue,
        history: history,
        onRetryHistory: () =>
            ref.invalidate(meetingHistoryProvider(membershipId)),
      );
    }

    return AppScaffold(
      title: person.value?.fullName ?? 'Disciple',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xs),
          body,
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static bool _isRefusal(Object e) =>
      e is DiscipleshipFailure && e.code == DbFailureCode.forbidden;
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.person,
    required this.journey,
    required this.history,
    required this.onRetryHistory,
  });

  final DiscipleContext person;
  final DiscipleJourney journey;
  final AsyncValue<List<MeetingHistoryEntry>> history;
  final VoidCallback onRetryHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(meetingSummaryProvider(person.membershipId))
        .value;
    final ministry = ref.watch(myMinistryContextProvider).value;
    final isMyDisciple =
        ministry?.myDisciples.any(
          (d) => d.churchMembershipId == person.membershipId,
        ) ??
        false;
    final entries = history.value ?? const <MeetingHistoryEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the person is now comes first.
        CurrentLessonCard(
          journey: journey,
          history: entries,
          disciplerName: person.disciplerName,
          lastRecordedMeetingAt: summary?.lastRecordedMeetingAt,
          footer: _LessonActions(person: person, journey: journey),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeading('Meetings'),
        if (summary != null) ...[
          // Oversight view: a run of recorded absences is stated as a fact.
          MeetingFactPills(summary: summary, includeConsecutive: true),
          const SizedBox(height: AppSpacing.sm),
        ],
        history.when(
          loading: () => const SizedBox(height: 160, child: LoadingState()),
          error: (e, _) => SizedBox(
            height: 240,
            child: ErrorState.load(
              subject: 'the meeting history',
              error: e,
              onRetry: onRetryHistory,
            ),
          ),
          data: (rows) => MeetingCalendar(
            entries: rows,
            emptyMessage: 'No meetings recorded for ${person.firstName} yet.',
            actionBuilder: journey.canRecord
                ? (day, hasMeeting) => _RecordAction(
                    person: person,
                    day: day,
                    hasMeeting: hasMeeting,
                    onBehalf: !isMyDisciple,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// "Record a meeting today", or "Record a meeting on Oct 3" when an
/// earlier day without a meeting is selected in the calendar, which opens
/// the form on that date.
class _RecordAction extends StatelessWidget {
  const _RecordAction({
    required this.person,
    required this.day,
    required this.hasMeeting,
    required this.onBehalf,
  });

  final DiscipleContext person;
  final DateTime? day;
  final bool hasMeeting;
  final bool onBehalf;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earlier = day != null && !hasMeeting && day!.isBefore(today)
        ? day
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: earlier == null
              ? 'Record a meeting today'
              : 'Record a meeting on ${AppFormat.shortDate(earlier.toUtc())}',
          icon: Icons.add_rounded,
          requiresConnection: true,
          offlineAction: 'record a meeting',
          onPressed: () => context.push(
            Routes.recordMeetingFor(person.membershipId, on: earlier),
          ),
        ),
        if (onBehalf && person.disciplerName != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            "On ${person.disciplerName}'s behalf",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Mark the current lesson completed, or undo the latest completion while
/// the window is open (ADR-015). Shown only when the journey's courtesy
/// flags allow it; the database decides again on every call.
///
/// Marking completed asks for confirmation first, stating the meetings
/// recorded and what changes, because the undo window closes as soon as a
/// meeting is recorded on the next lesson.
class _LessonActions extends ConsumerWidget {
  const _LessonActions({required this.person, required this.journey});

  final DiscipleContext person;
  final DiscipleJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lessonProgressControllerProvider);
    final controller = ref.read(lessonProgressControllerProvider.notifier);
    final history =
        ref.watch(meetingHistoryProvider(person.membershipId)).value ??
        const <MeetingHistoryEntry>[];
    final membershipId = person.membershipId;
    final current = journey.currentLesson;
    final undoable = journey.undoableLesson;
    final canComplete = current?.canComplete ?? false;
    if (!canComplete && undoable == null && state.error == null) {
      return const SizedBox.shrink();
    }

    Future<void> complete(JourneyLesson lesson) async {
      final meetings = [
        for (final e in history)
          if (e.lessonNumber == lesson.number && !e.isVoided) e,
      ];
      final hasNext = lesson.number < journey.lessonsTotal;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Mark Lesson ${lesson.number} completed?',
        message: [
          '${person.firstName} has ${lesson.countLine.toLowerCase()} on '
              'Lesson ${lesson.number} (${lesson.title})'
              '${meetings.isEmpty ? '' : ': ${outcomeBreakdown(meetings)}'}.',
          if (hasNext)
            'Lesson ${lesson.number + 1} becomes the current lesson for '
                '${person.firstName}, their Discipler and their Leader. New '
                'meetings are recorded on Lesson ${lesson.number + 1}.'
          else
            'This is the last lesson of the curriculum.',
          'You can undo this until the first meeting on the next lesson is '
              'recorded. After that, only the Coordinator can reopen it.',
        ].join('\n\n'),
        confirmLabel: 'Mark completed',
      );
      if (!confirmed || !context.mounted) return;
      final ok = await controller.complete(membershipId, lesson.lessonId);
      if (!ok || !context.mounted) return;
      final next = hasNext
          ? ' Lesson ${lesson.number + 1} is now current.'
          : '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Lesson ${lesson.number} completed.$next'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => controller.undo(membershipId, lesson.lessonId),
            ),
          ),
        );
    }

    Future<void> undo(JourneyLesson lesson) async {
      final ok = await controller.undo(membershipId, lesson.lessonId);
      if (!ok || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Lesson ${lesson.number} is in progress again.'),
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canComplete) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Mark Lesson ${current!.number} completed',
            icon: Icons.check_circle_outline_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: state.inFlight == 'complete:${current.lessonId}',
            requiresConnection: true,
            offlineAction: 'mark this lesson completed',
            onPressed: () => complete(current),
          ),
        ],
        if (undoable != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextLink(
              label: 'Undo Lesson ${undoable.number} completion',
              requiresConnection: true,
              offlineAction: 'undo this completion',
              onTap: state.isBusy ? null : () => undo(undoable),
            ),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              state.error!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
