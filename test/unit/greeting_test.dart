import 'package:discipletrack/core/widgets/app_page_header.dart';
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
}
