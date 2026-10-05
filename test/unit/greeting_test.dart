import 'package:discipletrack/core/widgets/app_page_header.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/presentation/discipleship_ui.dart';
import 'package:discipletrack/features/home/presentation/home_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the header greeting follows the local time of day', () {
    expect(greetingFor(DateTime(2026, 10, 2, 7)), 'Good morning');
    expect(greetingFor(DateTime(2026, 10, 2, 11, 59)), 'Good morning');
    expect(greetingFor(DateTime(2026, 10, 2, 12)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 10, 2, 17, 59)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 10, 2, 18)), 'Good evening');
    expect(greetingFor(DateTime(2026, 10, 2, 23)), 'Good evening');
  });

  test('the slogan is the same all day and changes the next day', () {
    final morning = sloganFor(DateTime(2026, 10, 5, 7));
    expect(sloganFor(DateTime(2026, 10, 5, 22)), morning);
    expect(sloganFor(DateTime(2026, 10, 6, 7)), isNot(morning));
    for (final s in slogans) {
      expect(s.highlight, isNotEmpty);
    }
  });

  test('Late has its own colour, distinct from Present', () {
    expect(
      OutcomeSelector.toneOf(AttendanceOutcome.late),
      isNot(OutcomeSelector.toneOf(AttendanceOutcome.present)),
    );
  });
}
