import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/curriculum/data/curriculum_repository.dart';
import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:discipletrack/features/curriculum/domain/workbook.dart';

/// Lesson ids for the fakes: `lesson-1` to `lesson-10`.
String sampleLessonId(int number) => 'lesson-$number';

const _titles = [
  'Salvation',
  'Assurance',
  'Prayer',
  'Local Church',
  'Discipleship',
  'The Future',
  'Spiritual Formation',
  'Faith',
  'Conversation',
  'Loving God',
];

/// The ten lessons with the first [open] open, and the Discipler tier on
/// them when [discipler] is set.
List<LessonAccess> sampleLessonAccess({int open = 0, bool discipler = false}) =>
    [
      for (var n = 1; n <= 10; n++)
        LessonAccess(
          lessonId: sampleLessonId(n),
          number: n,
          title: _titles[n - 1],
          theme: n <= open ? _titles[n - 1] : null,
          discipleTier: n <= open,
          disciplerTier: n <= open && discipler,
        ),
    ];

ContentBlock _block(
  int number,
  int ordinal,
  BlockType type,
  Map<String, dynamic> body, {
  String? section,
  ContentTier tier = ContentTier.disciple,
}) => ContentBlock(
  blockId: 'b-$number-$ordinal',
  lessonId: sampleLessonId(number),
  ordinal: ordinal,
  sectionLabel: section,
  type: type,
  tier: tier,
  body: body,
);

/// A metadata publication of one lesson as the database returns it: the
/// Disciple tier always, the Discipler tier only when [discipler] is set.
LessonContent sampleLessonContent(int number, {bool discipler = false}) =>
    LessonContent(
      lessonId: sampleLessonId(number),
      blocks: [
        _block(number, 1, BlockType.lessonTheme, {'text': _titles[number - 1]}),
        _block(number, 2, BlockType.topicList, {
          'items': ['First topic', 'Second topic'],
        }),
        _block(number, 3, BlockType.sectionHeading, {
          'title': 'Opening section',
        }, section: 'A'),
        _block(number, 4, BlockType.scriptureReferences, {
          'refs': ['John 3:16', 'Romans 10:9-13'],
        }, section: 'A'),
        if (discipler)
          _block(number, 5, BlockType.moduleHeading, {
            'number': 1,
            'title': 'The definition of one on one discipleship',
          }, tier: ContentTier.discipler),
      ],
    );

/// Serves configured lesson lists and content; a lesson without content
/// is refused, as `get_lesson_content()` refuses it.
class FakeCurriculumRepository implements CurriculumRepository {
  FakeCurriculumRepository({
    List<LessonAccess>? access,
    Map<String, LessonContent>? content,
    this.offline = false,
  }) : access = access ?? sampleLessonAccess(),
       content = content ?? {};

  List<LessonAccess> access;
  Map<String, LessonContent> content;

  /// Each Disciple context's lesson list; [access] for any other.
  Map<String, List<LessonAccess>> contextAccess = {};

  /// Every read fails as an unreachable server would.
  bool offline;

  final contentReads = <({String lessonId, String? forMembershipId})>[];

  static const _network = CurriculumFailure(
    'offline',
    code: DbFailureCode.network,
  );

  @override
  Future<List<LessonAccess>> fetchLessonAccess({
    String? forMembershipId,
  }) async {
    if (offline) throw _network;
    return forMembershipId == null
        ? access
        : contextAccess[forMembershipId] ?? access;
  }

  /// Answer keys for checking, by block id: one answer per blank.
  Map<String, List<String>> keys = {};

  @override
  Future<List<({String blockId, BlankResult result})>> checkAnswers(
    String lessonId,
    Map<String, List<String>> responses,
  ) async {
    if (offline) throw _network;
    String norm(String x) =>
        x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    return [
      for (final e in responses.entries)
        for (final (i, given) in e.value.indexed)
          if (given.trim().isNotEmpty && i < (keys[e.key]?.length ?? 0))
            (
              blockId: e.key,
              result: BlankResult(
                blank: i,
                correct: norm(given) == norm(keys[e.key]![i]),
                answer: keys[e.key]![i],
              ),
            ),
    ];
  }

  @override
  Future<Map<String, String>> fetchCovers() async {
    if (offline) throw _network;
    return const {};
  }

  @override
  Future<LessonContent> fetchLessonContent(
    String lessonId, {
    String? forMembershipId,
  }) async {
    contentReads.add((lessonId: lessonId, forMembershipId: forMembershipId));
    if (offline) throw _network;
    final lesson = content[lessonId];
    if (lesson == null) {
      throw const CurriculumFailure(
        "This lesson isn't open to you.",
        code: DbFailureCode.forbidden,
      );
    }
    return lesson;
  }

  @override
  Future<ReadableContent> fetchMyReadableContent(
    String userId, {
    Iterable<String> contextIds = const [],
  }) async {
    if (offline) throw _network;
    return ReadableContent(
      userId: userId,
      savedAt: DateTime.utc(2026, 10, 6),
      lessons: access,
      contexts: {
        for (final id in contextIds) id: contextAccess[id] ?? const [],
      },
      blocks: [for (final c in content.values) ...c.blocks],
    );
  }
}

/// The device copy, held in memory.
class MemoryCurriculumCacheStore extends CurriculumCacheStore {
  MemoryCurriculumCacheStore([this.copy]) : super(enabled: true);

  ReadableContent? copy;

  @override
  Future<ReadableContent?> read(String userId) async =>
      copy?.userId == userId ? copy : null;

  @override
  Future<void> write(ReadableContent content) async => copy = content;

  @override
  Future<void> clearAll() async => copy = null;
}
