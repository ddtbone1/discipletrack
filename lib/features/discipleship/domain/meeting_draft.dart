import 'package:flutter/foundation.dart';

import '../../../core/format/app_format.dart';
import 'attendance_outcome.dart';

/// One row of `get_recording_options()`: a Disciple of the same Discipler,
/// with the lesson they are on.
@immutable
class RecordingOption {
  const RecordingOption({
    required this.membershipId,
    required this.fullName,
    required this.isTarget,
    required this.lessonId,
    required this.lessonNumber,
    required this.lessonTitle,
    required this.pairedSince,
    required this.disciplerDGroupMembershipId,
    required this.disciplerName,
    required this.disciplerSince,
  });

  factory RecordingOption.fromMap(Map<String, dynamic> map) => RecordingOption(
    membershipId: map['church_membership_id'] as String,
    fullName: map['full_name'] as String,
    isTarget: map['is_target'] as bool,
    lessonId: map['lesson_id'] as String,
    lessonNumber: map['lesson_number'] as int,
    lessonTitle: map['lesson_title'] as String,
    pairedSince: DateTime.parse(map['paired_since'] as String),
    disciplerDGroupMembershipId:
        map['discipler_d_group_membership_id'] as String,
    disciplerName: map['discipler_name'] as String,
    disciplerSince: DateTime.parse(map['discipler_since'] as String),
  );

  final String membershipId;
  final String fullName;
  final bool isTarget;
  final String lessonId;
  final int lessonNumber;
  final String lessonTitle;
  final DateTime pairedSince;
  final String disciplerDGroupMembershipId;
  final String disciplerName;
  final DateTime disciplerSince;
}

/// What Record a meeting will send. The database validates everything
/// again; this only lets the form explain a problem before sending.
@immutable
class MeetingDraft {
  const MeetingDraft({
    required this.lessonId,
    required this.lessonNumber,
    required this.disciplerDGroupMembershipId,
    required this.occurredOn,
    required this.outcomes,
    required this.names,
    this.notes,
  });

  final String lessonId;
  final int lessonNumber;
  final String disciplerDGroupMembershipId;

  /// The calendar day of the meeting, in the person's local time.
  final DateTime occurredOn;

  /// Church membership id to outcome. Every listed person has one.
  final Map<String, AttendanceOutcome> outcomes;

  /// Church membership id to name, for messages.
  final Map<String, String> names;
  final String? notes;

  /// The moment sent as `occurred_at`: today's meeting is recorded as now,
  /// an earlier day as noon local time, so it never lands in the future.
  DateTime occurredAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(occurredOn.year, occurredOn.month, occurredOn.day);
    return day == today ? now : DateTime(day.year, day.month, day.day, 12);
  }

  /// The first problem the form can see, or null.
  String? problem(DateTime now) {
    if (outcomes.isEmpty) {
      return 'Choose at least one Disciple for this meeting.';
    }
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(
      occurredOn.year,
      occurredOn.month,
      occurredOn.day,
    ).isAfter(today)) {
      return 'That date is in the future. Meetings are recorded after they '
          'happen.';
    }
    return null;
  }

  /// "Records a Lesson 4 meeting on Oct 1 · counts for Diana", or with who
  /// doesn't count: "· Diana: Absent, doesn't count".
  String get reviewLine {
    final counted = [
      for (final e in outcomes.entries)
        if (e.value.countsTowardLesson) _first(names[e.key]),
    ];
    final notCounted = [
      for (final e in outcomes.entries)
        if (!e.value.countsTowardLesson)
          "${_first(names[e.key])}: ${e.value.label}, doesn't count",
    ];
    final date = AppFormat.shortDate(occurredOn.toUtc());
    return [
      'Records a Lesson $lessonNumber meeting on $date',
      if (counted.isNotEmpty) 'counts for ${_list(counted)}',
      ...notCounted,
    ].join(' · ');
  }

  static String _first(String? name) =>
      (name ?? 'Disciple').trim().split(RegExp(r'\s+')).first;

  static String _list(List<String> items) => items.length <= 2
      ? items.join(' and ')
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}
