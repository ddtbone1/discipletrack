import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The meeting count a lesson needs is an open product decision (N1). The
/// database answers it through one policy function, currently a
/// placeholder, and denies clients the pre-decision required_meetings
/// column. This keeps the app from adopting that column as a rule.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('no app code reads required_meetings', () {
    final offenders = [
      for (final f in sources)
        if (f.readAsStringSync().contains('required_meetings')) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
