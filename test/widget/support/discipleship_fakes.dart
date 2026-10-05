/// Discipleship fakes and sample values for widget tests (Slice 5).
library;

import 'package:discipletrack/features/discipleship/data/discipleship_repository.dart';
import 'package:discipletrack/features/discipleship/domain/disciple_progress_summary.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_draft.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';

/// Records discipleship operations and returns whatever the test configured.
/// A configured [readFailure] fails every read; [recordFailure] fails
/// recording.
class FakeDiscipleshipRepository implements DiscipleshipRepository {
  List<DiscipleProgressSummary> disciples = const [];
  Map<String, DiscipleContext> contexts = {};
  Map<String, DiscipleJourney> journeys = {};
  Map<String, List<MeetingHistoryEntry>> histories = {};
  Map<String, List<RecordingOption>> options = {};
  Map<String, MeetingSummary> summaries = {};
  ProgressSummary progress = const ProgressSummary();
  DiscipleshipFailure? progressFailure;
  final completed = <String>[];
  final undone = <String>[];
  DiscipleshipFailure? readFailure;
  DiscipleshipFailure? recordFailure;
  final recorded = <MeetingDraft>[];

  Future<T> _read<T>(T Function() value) async {
    if (readFailure != null) throw readFailure!;
    return value();
  }

  @override
  Future<List<DiscipleProgressSummary>> fetchMyDisciples() =>
      _read(() => disciples);

  @override
  Future<DiscipleContext> fetchContext(String membershipId) =>
      _read(() => contexts[membershipId]!);

  @override
  Future<DiscipleJourney> fetchJourney(String membershipId) =>
      _read(() => journeys[membershipId]!);

  @override
  Future<List<MeetingHistoryEntry>> fetchHistory(String membershipId) =>
      _read(() => histories[membershipId] ?? const []);

  @override
  Future<MeetingSummary> fetchMeetingSummary(String membershipId) => _read(
    () =>
        summaries[membershipId] ??
        const MeetingSummary(
          meetingsAttended: 0,
          recordedAbsences: 0,
          excused: 0,
          consecutiveRecordedAbsences: 0,
        ),
  );

  @override
  Future<ProgressSummary> fetchProgressSummary() => _read(() => progress);

  @override
  Future<List<RecordingOption>> fetchRecordingOptions(String membershipId) =>
      _read(() => options[membershipId] ?? const []);

  @override
  Future<void> completeLesson(String membershipId, String lessonId) async {
    completed.add(lessonId);
    if (progressFailure != null) throw progressFailure!;
  }

  @override
  Future<void> undoLessonCompletion(
    String membershipId,
    String lessonId,
  ) async {
    undone.add(lessonId);
    if (progressFailure != null) throw progressFailure!;
  }

  @override
  Future<String> recordMeeting(MeetingDraft draft, {DateTime? now}) async {
    recorded.add(draft);
    if (recordFailure != null) throw recordFailure!;
    return 'meeting-${recorded.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A journey of [total] lessons: [completed] confirmed, the next current in
/// [currentState], the rest locked.
DiscipleJourney sampleJourney({
  int total = 12,
  int completed = 3,
  LessonState currentState = LessonState.inProgress,
  int credited = 2,
  int? recommended,
  bool canRecord = false,
  bool canComplete = false,
  bool canUndoPrevious = false,
}) => DiscipleJourney([
  for (var n = 1; n <= total; n++)
    JourneyLesson(
      lessonId: 'lesson-$n',
      number: n,
      title: 'Lesson title $n',
      state: n <= completed
          ? LessonState.completed
          : n == completed + 1
          ? currentState
          : LessonState.locked,
      creditedCount: n == completed + 1 ? credited : 0,
      recommendedMeetings: recommended,
      isCurrent: n == completed + 1,
      startedAt: n == completed + 1 ? DateTime.utc(2026, 9, 3, 12) : null,
      readyAt: currentState == LessonState.submitted && n == completed + 1
          ? DateTime.utc(2026, 9, 30, 12)
          : null,
      submittedByName:
          currentState == LessonState.submitted && n == completed + 1
          ? 'Mark Reyes'
          : null,
      canRecord: canRecord && n == completed + 1,
      canComplete: canComplete && n == completed + 1,
      canUndo: canUndoPrevious && n == completed,
      completedAt: n <= completed ? DateTime.utc(2026, 9, 12, 12) : null,
      confirmedByName: n <= completed ? 'Mark Reyes' : null,
    ),
]);

RecordingOption sampleOption({
  String id = 'cm-diana',
  String name = 'Diana Cruz',
  bool isTarget = true,
  int lesson = 4,
}) => RecordingOption(
  membershipId: id,
  fullName: name,
  isTarget: isTarget,
  lessonId: 'lesson-$lesson',
  lessonNumber: lesson,
  lessonTitle: 'Lesson title $lesson',
  pairedSince: DateTime.utc(2026, 8, 1),
  disciplerDGroupMembershipId: 'dgm-mark',
  disciplerName: 'Mark Reyes',
  disciplerSince: DateTime.utc(2026, 7, 1),
);
