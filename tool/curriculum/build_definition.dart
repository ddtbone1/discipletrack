// Builds the FULL curriculum definition: the metadata definition with every
// converted lesson (supabase/curriculum/full/lesson-NN.json) in place of
// its metadata (ADR-019 decisions 11 and 15).
//
//   dart run tool/curriculum/build_definition.dart "<licence reference>"
//
// Writes, in the git-ignored supabase/curriculum/full/:
//   definition.json      for tool/publish_curriculum.ps1 -ContentLevel FULL
//   publish_local.sql    the same publication for the local church
// Apply the local one with:
//   Get-Content supabase/curriculum/full/publish_local.sql |
//     docker exec -i supabase_db_discipletrack psql -U postgres -v ON_ERROR_STOP=1
import 'dart:convert';
import 'dart:io';

import 'convert_lesson.dart' show fullDir, lessonPath, metadataPath;

void main(List<String> args) {
  final licence = args.isEmpty ? '' : args.single.trim();
  if (licence.isEmpty) {
    stderr.writeln('A FULL publication needs a licence reference.');
    exitCode = 2;
    return;
  }
  final metadata = (jsonDecode(File(metadataPath).readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final lessons = <Map<String, dynamic>>[];
  final full = <int>[];
  for (final l in (metadata['lessons'] as List).cast<Map<String, dynamic>>()) {
    final n = l['number'] as int;
    final file = File(lessonPath(n));
    if (file.existsSync()) {
      lessons.add((jsonDecode(file.readAsStringSync()) as Map).cast());
      full.add(n);
    } else {
      lessons.add(l);
    }
  }
  final definition = jsonEncode({'lessons': lessons});
  File('$fullDir/definition.json').writeAsStringSync(definition);

  const tag = r'$curriculum$';
  final quoted = licence.replaceAll("'", "''");
  File('$fullDir/publish_local.sql').writeAsStringSync('''
select public.publish_curriculum(
  'c0000000-0000-4000-8000-000000000001',
  $tag$definition$tag::jsonb,
  'FULL',
  '$quoted',
  'a0000000-0000-4000-8000-000000000001'
);
''');
  stdout.writeln('Full lessons: ${full.join(', ')}; others metadata.');
}
