import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/postgrest_failure.dart';
import '../../membership/application/membership_providers.dart';
import '../data/discipleship_repository.dart';
import '../domain/disciple_progress_summary.dart';
import '../domain/journey.dart';
import '../domain/meeting_draft.dart';
import '../domain/meeting_history_entry.dart';

/// Discipleship reads need a connection: progress is not part of the Slice 4
/// offline snapshot (plan decision 10), so offline these fail with a network
/// failure and the screens say so.
bool _isActive(Ref ref) =>
    ref.watch(myMembershipProvider).value?.status.grantsChurchAccess ?? false;

/// The caller's own currently assigned Disciples, longest since their last
/// recorded meeting first.
final myDisciplesProvider = FutureProvider<List<DiscipleProgressSummary>>((
  ref,
) async {
  if (!_isActive(ref)) return const [];
  final rows = await ref
      .watch(discipleshipRepositoryProvider)
      .fetchMyDisciples();
  return [...rows]..sort(DiscipleProgressSummary.byLongestSinceLastMeeting);
});

/// A D Group's current Disciples with their progress, by church membership
/// id, for the group's Leader and the Coordinator. Empty when the caller
/// is not active; refused for anyone else (the server decides).
final groupProgressProvider =
    FutureProvider.family<Map<String, DiscipleProgressSummary>, String>((
      ref,
      groupId,
    ) async {
      if (!_isActive(ref)) return const {};
      final rows = await ref
          .watch(discipleshipRepositoryProvider)
          .fetchGroupProgress(groupId);
      return {for (final r in rows) r.membershipId: r};
    });

final discipleContextProvider = FutureProvider.family<DiscipleContext, String>(
  (ref, membershipId) =>
      ref.watch(discipleshipRepositoryProvider).fetchContext(membershipId),
);

final discipleJourneyProvider = FutureProvider.family<DiscipleJourney, String>(
  (ref, membershipId) =>
      ref.watch(discipleshipRepositoryProvider).fetchJourney(membershipId),
);

final meetingHistoryProvider =
    FutureProvider.family<List<MeetingHistoryEntry>, String>(
      (ref, membershipId) =>
          ref.watch(discipleshipRepositoryProvider).fetchHistory(membershipId),
    );

final meetingSummaryProvider = FutureProvider.family<MeetingSummary, String>(
  (ref, membershipId) => ref
      .watch(discipleshipRepositoryProvider)
      .fetchMeetingSummary(membershipId),
);

/// The caller's own church membership id, when ACTIVE. Their own journey is
/// read with it, through the same per-person reads as anyone else's.
final myMembershipIdProvider = Provider<String?>((ref) {
  final m = ref.watch(myMembershipProvider).value;
  return m != null && m.status.grantsChurchAccess ? m.id : null;
});

/// The caller's own journey, or null when they have no ACTIVE membership.
final myJourneyProvider = FutureProvider<DiscipleJourney?>((ref) async {
  final id = ref.watch(myMembershipIdProvider);
  if (id == null) return null;
  return ref.watch(discipleJourneyProvider(id).future);
});

/// Figures for Home within the caller's scope.
final progressSummaryProvider = FutureProvider<ProgressSummary?>((ref) async {
  if (!_isActive(ref)) return null;
  return ref.watch(discipleshipRepositoryProvider).fetchProgressSummary();
});

final recordingOptionsProvider =
    FutureProvider.family<List<RecordingOption>, String>(
      (ref, membershipId) => ref
          .watch(discipleshipRepositoryProvider)
          .fetchRecordingOptions(membershipId),
    );

/// Whether a meeting is being sent, and the last failure.
@immutable
class RecordMeetingState {
  const RecordMeetingState({this.isSending = false, this.error});

  final bool isSending;
  final DiscipleshipFailure? error;
}

/// Sends one meeting and refreshes what it changes: each participant's
/// journey and history, and My Disciples. A second tap while sending is
/// ignored. A conflict refreshes the recording options, because it means
/// what the form showed was stale.
class RecordMeetingController extends Notifier<RecordMeetingState> {
  @override
  RecordMeetingState build() => const RecordMeetingState();

  /// True when the meeting was recorded.
  Future<bool> record(MeetingDraft draft) async {
    if (state.isSending) return false;
    state = const RecordMeetingState(isSending: true);
    try {
      await ref.read(discipleshipRepositoryProvider).recordMeeting(draft);
      _refresh(draft);
      state = const RecordMeetingState();
      return true;
    } on DiscipleshipFailure catch (e) {
      if (e.code == DbFailureCode.conflict) {
        ref.invalidate(recordingOptionsProvider);
      }
      state = RecordMeetingState(error: e);
      return false;
    }
  }

  void clearError() => state = const RecordMeetingState();

  void _refresh(MeetingDraft draft) {
    for (final id in draft.outcomes.keys) {
      ref
        ..invalidate(discipleJourneyProvider(id))
        ..invalidate(meetingHistoryProvider(id))
        ..invalidate(meetingSummaryProvider(id))
        ..invalidate(recordingOptionsProvider(id));
    }
    ref
      ..invalidate(myDisciplesProvider)
      ..invalidate(groupProgressProvider)
      ..invalidate(progressSummaryProvider);
  }
}

/// Which lesson action is running for whom, and the last failure.
@immutable
class LessonProgressState {
  const LessonProgressState({this.inFlight, this.error});

  /// `complete:<lesson id>` or `undo:<lesson id>`.
  final String? inFlight;
  final DiscipleshipFailure? error;

  bool get isBusy => inFlight != null;
}

/// Marks a lesson completed or undoes it (ADR-015), one action at a time,
/// and refreshes what it changes: the journey everyone sees, My Disciples
/// and the recording options.
class LessonProgressController extends Notifier<LessonProgressState> {
  @override
  LessonProgressState build() => const LessonProgressState();

  DiscipleshipRepository get _repo => ref.read(discipleshipRepositoryProvider);

  Future<bool> complete(String membershipId, String lessonId) => _run(
    'complete:$lessonId',
    membershipId,
    () => _repo.completeLesson(membershipId, lessonId),
  );

  Future<bool> undo(String membershipId, String lessonId) => _run(
    'undo:$lessonId',
    membershipId,
    () => _repo.undoLessonCompletion(membershipId, lessonId),
  );

  Future<bool> _run(
    String key,
    String membershipId,
    Future<void> Function() action,
  ) async {
    if (state.isBusy) return false;
    state = LessonProgressState(inFlight: key);
    try {
      await action();
      _refresh(membershipId);
      state = const LessonProgressState();
      return true;
    } on DiscipleshipFailure catch (e) {
      if (e.code == DbFailureCode.conflict) _refresh(membershipId);
      state = LessonProgressState(error: e);
      return false;
    }
  }

  void _refresh(String membershipId) {
    ref
      ..invalidate(discipleJourneyProvider(membershipId))
      ..invalidate(recordingOptionsProvider)
      ..invalidate(myDisciplesProvider)
      ..invalidate(groupProgressProvider);
  }
}

/// Which void is running, and the last failure.
@immutable
class MeetingVoidState {
  const MeetingVoidState({this.inFlight, this.error});

  /// `meeting:<id>` or `participant:<id>`.
  final String? inFlight;
  final DiscipleshipFailure? error;

  bool get isBusy => inFlight != null;
}

/// Voids a meeting or one participant, one at a time, then refreshes
/// everything a void can change. A meeting void can change every
/// participant's progress, so the per-person reads are refreshed for
/// everyone, not only the person on screen.
class MeetingVoidController extends Notifier<MeetingVoidState> {
  @override
  MeetingVoidState build() => const MeetingVoidState();

  DiscipleshipRepository get _repo => ref.read(discipleshipRepositoryProvider);

  Future<bool> voidMeeting(String meetingId) =>
      _run('meeting:$meetingId', () => _repo.voidMeeting(meetingId));

  Future<bool> voidParticipant(String participantId) => _run(
    'participant:$participantId',
    () => _repo.voidParticipant(participantId),
  );

  Future<bool> _run(String key, Future<void> Function() action) async {
    if (state.isBusy) return false;
    state = MeetingVoidState(inFlight: key);
    try {
      await action();
      _refresh();
      state = const MeetingVoidState();
      return true;
    } on DiscipleshipFailure catch (e) {
      if (e.code == DbFailureCode.conflict) _refresh();
      state = MeetingVoidState(error: e);
      return false;
    }
  }

  void _refresh() {
    ref
      ..invalidate(discipleJourneyProvider)
      ..invalidate(meetingHistoryProvider)
      ..invalidate(meetingSummaryProvider)
      ..invalidate(recordingOptionsProvider)
      ..invalidate(myDisciplesProvider)
      ..invalidate(groupProgressProvider)
      ..invalidate(progressSummaryProvider);
  }
}

final meetingVoidControllerProvider =
    NotifierProvider<MeetingVoidController, MeetingVoidState>(
      MeetingVoidController.new,
    );

final lessonProgressControllerProvider =
    NotifierProvider<LessonProgressController, LessonProgressState>(
      LessonProgressController.new,
    );

final recordMeetingControllerProvider =
    NotifierProvider<RecordMeetingController, RecordMeetingState>(
      RecordMeetingController.new,
    );
