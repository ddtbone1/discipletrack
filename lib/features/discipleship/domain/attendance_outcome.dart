/// A Disciple's recorded outcome at one meeting (ADR-009, ADR-014).
///
/// Recorded explicitly in Record a meeting, the only place attendance
/// exists. Whether an outcome is credited is decided by the database;
/// [countsTowardLesson] only explains it on screen.
enum AttendanceOutcome {
  present('PRESENT', 'Present'),
  late('LATE', 'Late'),
  absent('ABSENT', 'Absent'),
  excused('EXCUSED', 'Excused');

  const AttendanceOutcome(this.db, this.label);

  final String db;
  final String label;

  /// Present and Late count toward the lesson; Absent and Excused don't.
  bool get countsTowardLesson => this == present || this == late;

  static AttendanceOutcome fromDb(String value) => values.firstWhere(
    (o) => o.db == value,
    orElse: () => throw ArgumentError('Unknown attendance outcome: $value'),
  );
}
