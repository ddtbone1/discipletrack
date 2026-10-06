import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/disciple_progress_summary.dart';
import '../domain/journey.dart';
import '../domain/meeting_draft.dart';
import '../domain/meeting_history_entry.dart';

/// A failed discipleship operation, with a message fit to show a person.
///
/// [reason] is the stable reason the database raised, kept so callers and
/// tests can branch on it without parsing the message.
class DiscipleshipFailure implements Exception, NetworkAwareFailure {
  const DiscipleshipFailure(
    this.message, {
    this.code = DbFailureCode.unknown,
    this.reason,
  });

  final String message;
  final DbFailureCode code;
  final String? reason;

  @override
  bool get isNetwork => code == DbFailureCode.network;

  @override
  String toString() => message;
}

/// Meetings, progress and the journey reads (Slice 5).
///
/// Every call is a controlled operation that authorizes the pair (caller,
/// person) in the database. Nothing here decides who may see or do what.
class DiscipleshipRepository {
  DiscipleshipRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own currently assigned Disciples.
  Future<List<DiscipleProgressSummary>> fetchMyDisciples() =>
      _guard('Could not load your Disciples.', () async {
        final rows = await _rows('list_disciple_progress', const {});
        return [for (final r in rows) DiscipleProgressSummary.fromMap(r)];
      });

  /// The current Disciples of a D Group with their progress, for the
  /// group's Leader and the Coordinator (`list_group_progress()`).
  Future<List<DiscipleProgressSummary>> fetchGroupProgress(String groupId) =>
      _guard("Could not load the group's progress.", () async {
        final rows = await _rows('list_group_progress', {
          'p_d_group_id': groupId,
        });
        return [for (final r in rows) DiscipleProgressSummary.fromMap(r)];
      });

  Future<DiscipleContext> fetchContext(String membershipId) =>
      _guard('Could not load this person.', () async {
        final rows = await _rows('get_disciple_context', {
          'p_membership_id': membershipId,
        });
        return DiscipleContext.fromMap(rows.single);
      });

  Future<DiscipleJourney> fetchJourney(String membershipId) => _guard(
    'Could not load this journey.',
    () async {
      final rows = await _rows('get_disciple_journey', {
        'p_membership_id': membershipId,
      });
      return DiscipleJourney([for (final r in rows) JourneyLesson.fromMap(r)]);
    },
  );

  /// Newest first.
  Future<List<MeetingHistoryEntry>> fetchHistory(String membershipId) =>
      _guard('Could not load the meeting history.', () async {
        final rows = await _rows('get_meeting_history', {
          'p_membership_id': membershipId,
        });
        return [for (final r in rows) MeetingHistoryEntry.fromMap(r)];
      });

  Future<MeetingSummary> fetchMeetingSummary(String membershipId) =>
      _guard('Could not load the meeting facts.', () async {
        final rows = await _rows('get_disciple_meeting_summary', {
          'p_membership_id': membershipId,
        });
        return MeetingSummary.fromMap(rows.single);
      });

  Future<ProgressSummary> fetchProgressSummary() =>
      _guard('Could not load your figures.', () async {
        final rows = await _rows('get_progress_summary', const {});
        return ProgressSummary.fromMap(rows.single);
      });

  /// The person opened from first, then their Discipler's other Disciples.
  Future<List<RecordingOption>> fetchRecordingOptions(String membershipId) =>
      _guard('Could not load who can be recorded.', () async {
        final rows = await _rows('get_recording_options', {
          'p_membership_id': membershipId,
        });
        return [for (final r in rows) RecordingOption.fromMap(r)];
      });

  /// `record_discipleship_meeting()`; returns the meeting id.
  Future<String> recordMeeting(MeetingDraft draft, {DateTime? now}) => _guard(
    'Could not record the meeting.',
    () async {
      final rows = await _rows('record_discipleship_meeting', {
        'p_discipler_d_group_membership_id': draft.disciplerDGroupMembershipId,
        'p_lesson_id': draft.lessonId,
        'p_occurred_at': draft
            .occurredAt(now ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'p_participants': [
          for (final e in draft.outcomes.entries)
            {'church_membership_id': e.key, 'attendance_status': e.value.db},
        ],
        'p_notes': draft.notes,
      });
      return rows.single['meeting_id'] as String;
    },
    names: draft.names,
  );

  /// `complete_lesson()` (ADR-015).
  Future<void> completeLesson(String membershipId, String lessonId) => _guard(
    'Could not mark the lesson completed.',
    () => _rows('complete_lesson', {
      'p_membership_id': membershipId,
      'p_lesson_id': lessonId,
    }),
  );

  /// `undo_lesson_completion()`, within the undo window.
  Future<void> undoLessonCompletion(String membershipId, String lessonId) =>
      _guard(
        'Could not undo the completion.',
        () => _rows('undo_lesson_completion', {
          'p_membership_id': membershipId,
          'p_lesson_id': lessonId,
        }),
      );

  /// `reopen_lesson_completion()`: Coordinator only; refused while a later
  /// lesson is completed or has a recorded meeting.
  Future<void> reopenLessonCompletion(String membershipId, String lessonId) =>
      _guard(
        'Could not reopen the lesson.',
        () => _rows('reopen_lesson_completion', {
          'p_membership_id': membershipId,
          'p_lesson_id': lessonId,
        }),
      );

  /// `void_discipleship_meeting()`: the whole meeting, for everyone in it.
  Future<void> voidMeeting(String meetingId) => _guard(
    'Could not void the meeting.',
    () => _rows('void_discipleship_meeting', {'p_meeting_id': meetingId}),
  );

  /// `void_meeting_participant()`: one person who should not have been
  /// listed. The meeting stays as recorded for everyone else.
  Future<void> voidParticipant(String participantId) => _guard(
    'Could not remove them from the meeting.',
    () =>
        _rows('void_meeting_participant', {'p_participant_id': participantId}),
  );

  Future<List<Map<String, dynamic>>> _rows(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(fn, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<T> _guard<T>(
    String fallback,
    Future<T> Function() action, {
    Map<String, String> names = const {},
  }) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw failureFrom(e, fallback, names: names);
    } on DiscipleshipFailure {
      rethrow;
    } on Exception {
      throw const DiscipleshipFailure(
        PostgrestFailure.networkMessage,
        code: DbFailureCode.network,
      );
    } catch (_) {
      throw DiscipleshipFailure(fallback);
    }
  }

  /// Maps a reason raised by the Slice 5 operations to the wording of plan
  /// section F3. A refusal about one person names them from [names] when
  /// the error detail identifies them. Exposed for tests.
  static DiscipleshipFailure failureFrom(
    PostgrestException e,
    String fallback, {
    Map<String, String> names = const {},
  }) {
    final detail = _detail(e.details);
    final name = names[detail['church_membership_id']] ?? 'This Disciple';
    final message = switch (e.message) {
      'participants_required' =>
        'Choose at least one Disciple for this meeting.',
      'duplicate_participant' =>
        'Each Disciple can be added once. Remove the duplicate and try again.',
      'invalid_attendance_status' =>
        'Choose Present, Late, Absent or Excused for each Disciple.',
      'occurred_at_required' => 'Choose the date of the meeting.',
      'occurred_at_in_future' =>
        'That date is in the future. Meetings are recorded after they happen.',
      'discipler_not_active_at_occurred_at' =>
        "The Discipler wasn't serving in this group on that date. Choose a "
            'date since they started.',
      'participant_not_assigned_at_occurred_at' =>
        "$name wasn't paired with this Discipler on that date. Choose a later "
            'date, or record without them.',
      'lesson_not_eligible' =>
        detail['lesson_number'] == null
            ? '$name has completed every lesson.'
            : '$name is on Lesson ${detail['lesson_number']}. Lessons are '
                  'recorded in order, one at a time.',
      'lesson_not_in_active_curriculum' =>
        "That lesson isn't part of your church's current curriculum.",
      'member_not_active' =>
        "$name is no longer an active member, so meetings can't be recorded "
            'for them.',
      'cannot_record_own_meeting' =>
        "You can't record a meeting you took part in as a Disciple. Ask your "
            'Discipler or Leader.',
      'lesson_not_completed' =>
        "That lesson isn't completed, so there's nothing to undo or reopen.",
      // A later completed lesson or a later recorded meeting locks an
      // earlier lesson. The refusals state the lock; they never suggest
      // voiding or undoing later progress to get around it.
      'later_lesson_completed' =>
        detail['later_lesson_number'] == null
            ? "A later lesson is already completed, so this lesson's "
                  'completion is locked.'
            : 'Lesson ${detail['later_lesson_number']} is already completed, '
                  'so Lesson ${detail['lesson_number']} is locked.',
      'next_lesson_started' =>
        'A meeting is already recorded on the next lesson, so Lesson '
            "${detail['lesson_number'] ?? ''}'s completion is locked and "
            "can't be undone.",
      'later_lesson_has_meetings' =>
        'Lesson ${detail['later_lesson_number'] ?? ''} already has a '
            "recorded meeting, so Lesson ${detail['lesson_number'] ?? ''} "
            "can't be reopened.",
      'eligibility_lesson_protected' =>
        "Lesson ${detail['lesson_number'] ?? ''} can't be reopened: this "
            "person's appointment as a Discipler rests on Lesson "
            "${detail['eligibility_lesson_number'] ?? ''}.",
      'cannot_void_own_meeting' =>
        "You can't void a meeting you took part in. Ask your Leader or the "
            'Coordinator.',
      'meeting_not_recorded' || 'participant_not_recorded' =>
        'This was already voided. Refresh to see the latest.',
      'void_meeting_instead' =>
        'This is the only person in the meeting. Void the whole meeting '
            'instead.',
      'cannot_act_on_own_lesson' =>
        "You can't mark or undo your own lesson. Your Discipler, Leader or "
            'the Coordinator can.',
      'not_authorized' =>
        "You can't do that for this person. Ask their Leader or the "
            'Coordinator.',
      'lesson_not_found' ||
      'meeting_not_found' ||
      'participant_not_found' ||
      'progress_not_found' =>
        "We couldn't find that anymore. It may have been changed. Refresh and "
            'try again.',
      _ => PostgrestFailure.friendlyMessage(e, fallback),
    };
    return DiscipleshipFailure(
      message,
      code: PostgrestFailure.codeOf(e),
      reason: e.message,
    );
  }

  static Map<String, dynamic> _detail(Object? details) {
    if (details is! String || details.isEmpty) return const {};
    try {
      final decoded = jsonDecode(details);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

final discipleshipRepositoryProvider = Provider<DiscipleshipRepository>((ref) {
  return DiscipleshipRepository(ref.watch(supabaseClientProvider));
});
