import 'package:discipletrack/features/curriculum/data/workbook_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'answers round-trip per person and lesson, and never cross people',
    () async {
      final store = WorkbookStore();
      await store.write('u1', 'l1', {
        'b-1': {'b0': 'beginning', 'f0': 'Oct 7'},
      });

      expect(await store.read('u1', 'l1'), {
        'b-1': {'b0': 'beginning', 'f0': 'Oct 7'},
      });
      expect(await store.read('u2', 'l1'), isEmpty);
      expect(await store.read('u1', 'l2'), isEmpty);
    },
  );

  test(
    'an empty workbook removes the entry; a damaged one reads as empty',
    () async {
      final store = WorkbookStore();
      await store.write('u1', 'l1', {
        'b-1': {'b0': 'x'},
      });
      await store.write('u1', 'l1', {});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);

      await prefs.setString('workbook.v1.u1.l1', 'not json');
      expect(await store.read('u1', 'l1'), isEmpty);
    },
  );
}
