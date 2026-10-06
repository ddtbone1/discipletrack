import 'package:flutter/foundation.dart';

import 'attendance_outcome.dart';

/// One row of `get_meeting_history()`: the person's recorded outcome at one
/// meeting. There is no "held" or "missed" label (ADR-014 decision 8).
@immutable
class MeetingHistoryEntry {
  const MeetingHistoryEntry({
    required this.meetingId,
    required this.participantId,
    required this.occurredAt,
    required this.lessonNumber,
    required this.lessonTitle,
    required this.outcome,
    required this.isCredited,
    required this.isVoided,
    this.isRemoved = false,
    this.ordinal,
    this.recordedByName,
    this.notes,
    this.voidedByName,
    this.voidedAt,
    this.canVoidMeeting = false,
    this.canVoidParticipant = false,
  });

  factory MeetingHistoryEntry.fromMap(Map<String, dynamic> map) =>
      MeetingHistoryEntry(
        meetingId: map['meeting_id'] as String,
        participantId: map['participant_id'] as String,
        occurredAt: DateTime.parse(map['occurred_at'] as String),
        lessonNumber: map['lesson_number'] as int,
        lessonTitle: map['lesson_title'] as String,
        outcome: AttendanceOutcome.fromDb(map['attendance_status'] as String),
        isCredited: map['is_credited'] as bool,
        isVoided:
            map['meeting_status'] == 'VOIDED' ||
            map['participant_status'] == 'VOIDED',
        isRemoved:
            map['participant_status'] == 'VOIDED' &&
            map['meeting_status'] != 'VOIDED',
        ordinal: map['ordinal'] as int?,
        recordedByName: map['recorded_by_name'] as String?,
        notes: map['notes'] as String?,
        voidedByName: map['voided_by_name'] as String?,
        voidedAt: map['voided_at'] == null
            ? null
            : DateTime.parse(map['voided_at'] as String),
        canVoidMeeting: map['can_void_meeting'] as bool? ?? false,
        canVoidParticipant: map['can_void_participant'] as bool? ?? false,
      );

  final String meetingId;
  final String participantId;
  final DateTime occurredAt;
  final int lessonNumber;
  final String lessonTitle;
  final AttendanceOutcome outcome;
  final bool isCredited;
  final bool isVoided;

  /// Only this person's row was voided (they were removed from a meeting
  /// that otherwise stands); the meeting itself is not voided.
  final bool isRemoved;

  /// Position among the lesson's credited meetings; null when not credited.
  final int? ordinal;
  final String? recordedByName;
  final String? notes;
  final String? voidedByName;

  /// When the meeting, or this row, was voided.
  final DateTime? voidedAt;

  /// Courtesy flags from the server for the viewer: whether they may void
  /// the whole meeting, and whether they may remove this person from it
  /// (false when the person is its only recorded participant). The void
  /// operations decide again; the app only shows actions from these.
  final bool canVoidMeeting;
  final bool canVoidParticipant;

  bool get canVoid => canVoidMeeting || canVoidParticipant;

  /// "Meeting 3 · Present · Counted", "Absent · Not counted · Recorded
  /// absence", "Excused · Not counted" (plan section F2).
  String get outcomeLine {
    if (isVoided) return '${outcome.label} · Voided';
    if (isCredited) {
      return [
        if (ordinal != null) 'Meeting $ordinal',
        outcome.label,
        'Counted',
      ].join(' · ');
    }
    return outcome == AttendanceOutcome.absent
        ? 'Absent · Not counted · Recorded absence'
        : '${outcome.label} · Not counted';
  }
}
