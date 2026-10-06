import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Meeting count does not determine lesson completion (ADR-017; N1 closed):
/// the Discipler decides. The legacy required_meetings column is denied to
/// clients and must never become a rule in the app, nor may a minimum or a
/// "typical" number creep back in as a progression gate.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('no app code reads required_meetings or a meeting minimum', () {
    const forbidden = [
      'required_meetings',
      'requiredMeetings',
      'submission_minimum',
      'submissionMinimum',
      'recommended_meetings',
      'recommendedMeetings',
    ];
    final offenders = [
      for (final f in sources)
        for (final word in forbidden)
          if (f.readAsStringSync().contains(word)) '${f.path}: $word',
    ];
    expect(offenders, isEmpty);
  });
}
