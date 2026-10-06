// Generates supabase/seed_curriculum.sql from the committed curriculum
// definition, so `npx supabase db reset` publishes the local church's
// curriculum through the real publish_curriculum() operation.
//
// The definition (supabase/curriculum/journey-metadata.json) is the only
// source; the SQL is derived. test/unit/curriculum_definition_test.dart
// fails when the committed SQL no longer matches it.
//
// Usage: dart run tool/generate_curriculum_seed.dart

import 'dart:io';

import 'curriculum_seed.dart';

void main() {
  final json = File(curriculumDefinitionPath).readAsStringSync();
  File(curriculumSeedPath).writeAsStringSync(curriculumSeedSql(json));
  stdout.writeln('Wrote $curriculumSeedPath');
}
