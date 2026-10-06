import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/format/app_format.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/discipleship_providers.dart';
import '../data/discipleship_repository.dart';
import '../domain/journey.dart';
import '../domain/journey_activity.dart';
import '../domain/meeting_history_entry.dart';
import 'activity_timeline.dart';
import 'current_lesson_card.dart';
import 'lesson_complete_dialog.dart';
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the person is now, with the first intents inside: record a
        // meeting and mark the lesson completed, side by side.
        CurrentLessonCard(
          journey: journey,
          history: entries,
          disciplerName: person.disciplerName,
          lastRecordedMeetingAt: summary?.lastRecordedMeetingAt,
          footer: _LessonActions(
            person: person,
            journey: journey,
            onBehalf: !isMyDisciple,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeading('Meetings'),
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
            // Void actions only where the server says the viewer may.
            entryActionBuilder: (e) => e.canVoid
                ? _VoidMenu(entry: e, firstName: person.firstName)
                : null,
            actionBuilder: journey.canRecord
                ? (day, hasMeeting) =>
                      day != null && !hasMeeting && day.isBefore(today)
                      ? _RecordAction(
                          person: person,
                          day: day,
                          hasMeeting: hasMeeting,
                          onBehalf: !isMyDisciple,
                        )
                      : null
                : null,
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: AppSpacing.sm),
          // Oversight view: a run of recorded absences is stated as a fact.
          MeetingFactPills(summary: summary, includeConsecutive: true),
        ],
        // Recent activity sits at the bottom of the page.
        if (kShowJourneyActivity) ...[
          const SizedBox(height: AppSpacing.lg),
          JourneyActivitySection(
            title: 'Recent activity',
            events: journeyActivity(journey, entries),
          ),
        ],
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
          variant: AppButtonVariant.record,
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

/// The lesson card's actions: Record a meeting today, Mark completed under
/// it, then undoing the latest completion
/// while the window is open (ADR-015). Shown only when the journey's
/// courtesy flags allow it; the database decides again on every call.
///
/// Marking completed asks for confirmation first, stating the meetings
/// recorded and what changes, because the undo window closes as soon as a
/// meeting is recorded on the next lesson.
class _LessonActions extends ConsumerWidget {
  const _LessonActions({
    required this.person,
    required this.journey,
    required this.onBehalf,
  });

  final DiscipleContext person;
  final DiscipleJourney journey;

  /// The viewer is not the person's Discipler, so recording is on the
  /// Discipler's behalf.
  final bool onBehalf;

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
    final canRecord = journey.canRecord;
    if (!canRecord && !canComplete && undoable == null && state.error == null) {
      return const SizedBox.shrink();
    }

    Future<void> complete(JourneyLesson lesson) async {
      final meetings = [
        for (final e in history)
          if (e.lessonNumber == lesson.number && !e.isVoided) e,
      ];
      final hasNext = lesson.number < journey.lessonsTotal;
      final confirmed = await showLessonCompleteDialog(
        context,
        firstName: person.firstName,
        lesson: lesson,
        lessonsTotal: journey.lessonsTotal,
        meetings: meetings,
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
            // Dismisses itself: the lesson card keeps "Undo" for as long as
            // the window is open, so a stale Undo never lingers here.
            persist: false,
            duration: const Duration(seconds: 6),
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

    final buttons = [
      if (canRecord)
        AppButton(
          variant: AppButtonVariant.record,
          label: 'Record a meeting today',
          icon: Icons.add_rounded,
          requiresConnection: true,
          offlineAction: 'record a meeting',
          onPressed: () =>
              context.push(Routes.recordMeetingFor(person.membershipId)),
        ),
      if (canComplete)
        AppButton(
          label: 'Mark Lesson ${current!.number} completed',
          icon: Icons.check_circle_outline_rounded,
          variant: AppButtonVariant.secondary,
          isLoading: state.inFlight == 'complete:${current.lessonId}',
          requiresConnection: true,
          offlineAction: 'mark this lesson completed',
          onPressed: () => complete(current),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          // Record a meeting today on top, Mark completed under it.
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            buttons[i],
          ],
        ],
        if (canRecord && onBehalf && person.disciplerName != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            "Recorded on ${person.disciplerName}'s behalf",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
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

enum _VoidChoice { meeting, participant }

/// The selected meeting's ⋮ menu: "Void meeting" and, when the meeting has
/// someone else in it, "Remove {name} from this meeting". Each asks first
/// with the shared confirmation dialog. Shown only from the server's
/// courtesy flags; the void operations decide again.
class _VoidMenu extends ConsumerWidget {
  const _VoidMenu({required this.entry, required this.firstName});

  final MeetingHistoryEntry entry;
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(meetingVoidControllerProvider).isBusy;
    return PopupMenuButton<_VoidChoice>(
      tooltip: 'Meeting actions',
      icon: const Icon(Icons.more_vert_rounded),
      enabled: !busy,
      onSelected: (choice) => _onSelected(context, ref, choice),
      itemBuilder: (_) => [
        if (entry.canVoidMeeting)
          const PopupMenuItem(
            value: _VoidChoice.meeting,
            child: Text('Void meeting'),
          ),
        if (entry.canVoidParticipant)
          PopupMenuItem(
            value: _VoidChoice.participant,
            child: Text('Remove $firstName from this meeting'),
          ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    _VoidChoice choice,
  ) async {
    final wholeMeeting = choice == _VoidChoice.meeting;
    if (ConnectionScope.isOffline(context)) {
      explainOffline(
        context,
        action: wholeMeeting
            ? 'void this meeting'
            : 'remove $firstName from this meeting',
      );
      return;
    }
    final confirmed = wholeMeeting
        ? await showConfirmDialog(
            context,
            title: 'Void this meeting?',
            message: [
              entry.isCredited
                  ? 'It will no longer count toward Lesson ${entry.lessonNumber}.'
                  : 'It will no longer count as a recorded outcome.',
              if (entry.canVoidParticipant)
                'It is voided for everyone in the meeting.',
              "This can't be undone; record it again if needed.",
            ].join(' '),
            confirmLabel: 'Void meeting',
          )
        : await showConfirmDialog(
            context,
            title: 'Remove $firstName from this meeting?',
            message:
                "$firstName's outcome will no longer count. The meeting stays "
                "as recorded for everyone else. This can't be undone.",
            confirmLabel: 'Remove',
          );
    if (!confirmed || !context.mounted) return;

    final controller = ref.read(meetingVoidControllerProvider.notifier);
    final ok = wholeMeeting
        ? await controller.voidMeeting(entry.meetingId)
        : await controller.voidParticipant(entry.participantId);
    if (!context.mounted) return;
    final message = ok
        ? (wholeMeeting
              ? 'Meeting voided'
              : '$firstName removed from the meeting')
        : ref.read(meetingVoidControllerProvider).error?.message ??
              'Could not void the meeting.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
