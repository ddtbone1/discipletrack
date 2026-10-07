import 'package:flutter/foundation.dart';

/// The two content tiers (ADR-019 decision 5). Mirrors `content_tier`.
enum ContentTier {
  disciple,
  discipler;

  static ContentTier fromDb(String value) => switch (value) {
    'DISCIPLE' => ContentTier.disciple,
    'DISCIPLER' => ContentTier.discipler,
    _ => throw ArgumentError('Unknown content_tier: $value'),
  };

  String get toDb => name.toUpperCase();
}

/// Mirrors `lesson_block_type`. A type this version of the app does not
/// know becomes [unknown] and renders nothing, so a later full
/// publication cannot break an older app.
enum BlockType {
  lessonTheme('LESSON_THEME'),
  topicList('TOPIC_LIST'),
  sectionHeading('SECTION_HEADING'),
  scriptureReferences('SCRIPTURE_REFERENCES'),
  moduleHeading('MODULE_HEADING'),
  keyObjective('KEY_OBJECTIVE'),
  banner('BANNER'),
  paragraph('PARAGRAPH'),
  fillIn('FILL_IN'),
  discussionPrompts('DISCUSSION_PROMPTS'),
  scenario('SCENARIO'),
  verseWriting('VERSE_WRITING'),
  assignments('ASSIGNMENTS'),
  disciplerNote('DISCIPLER_NOTE'),
  point('POINT'),
  figure('FIGURE'),
  selfCheck('SELF_CHECK'),
  signOff('SIGN_OFF'),
  assignment('ASSIGNMENT'),
  list('LIST'),
  heading('HEADING'),
  unknown('');

  /// The identifying types a METADATA publication holds (ADR-019).
  static const metadata = {
    lessonTheme,
    topicList,
    sectionHeading,
    scriptureReferences,
    moduleHeading,
  };

  const BlockType(this.db);

  final String db;

  static BlockType fromDb(String value) => BlockType.values.firstWhere(
    (t) => t.db == value && t != BlockType.unknown,
    orElse: () => BlockType.unknown,
  );
}

/// One published block of a lesson, as `get_lesson_content()` or
/// `get_my_readable_content()` returns it. [answers] is present only when
/// the database allowed the Discipler tier.
@immutable
class ContentBlock {
  const ContentBlock({
    required this.blockId,
    required this.lessonId,
    required this.ordinal,
    required this.type,
    required this.tier,
    required this.body,
    this.sectionLabel,
    this.answers,
  });

  factory ContentBlock.fromMap(Map<String, dynamic> map, {String? lessonId}) =>
      ContentBlock(
        blockId: map['block_id'] as String,
        lessonId: (map['lesson_id'] as String?) ?? lessonId ?? '',
        ordinal: map['ordinal'] as int,
        sectionLabel: map['section_label'] as String?,
        type: BlockType.fromDb(map['block_type'] as String),
        tier: ContentTier.fromDb(map['tier'] as String),
        body: ((map['body'] as Map?) ?? const {}).cast<String, dynamic>(),
        answers: map['answers'] as List<dynamic>?,
      );

  final String blockId;
  final String lessonId;
  final int ordinal;
  final String? sectionLabel;
  final BlockType type;
  final ContentTier tier;
  final Map<String, dynamic> body;
  final List<dynamic>? answers;

  String? get text => body['text'] as String?;
  String? get reference => body['reference'] as String?;
  String? get subtitle => body['subtitle'] as String?;

  /// The answers, one per blank, when the database returned them (the
  /// Discipler tier only). An entry may list several accepted answers.
  List<String> get answerList => [
    for (final a in answers ?? const []) a is List ? a.join(' / ') : '$a',
  ];
  String? get title => body['title'] as String?;

  /// How the Disciple answers this block: "write", "choice", "truefalse"
  /// or "task"; null for text that asks for nothing.
  String? get respond => body['respond'] as String?;

  /// A question's lettered or listed parts, each with its own answer kind.
  List<BlockPart> get parts => [
    for (final p in (body['parts'] as List?) ?? const [])
      BlockPart.fromMap((p as Map).cast<String, dynamic>()),
  ];

  /// A reading plan's field ("Date"): each item is a reading with a date
  /// to write.
  String? get field => body['field'] as String?;
  String? get note => body['note'] as String?;

  /// The number of blanks in the block's text and parts.
  int get blankCount => (body['blanks'] as int?) ?? 0;

  List<String> get items => [
    for (final i in (body['items'] as List?) ?? const []) '$i',
  ];
  List<String> get refs => [
    for (final r in (body['refs'] as List?) ?? const []) '$r',
  ];

  Map<String, dynamic> toMap() => {
    'block_id': blockId,
    'lesson_id': lessonId,
    'ordinal': ordinal,
    'section_label': sectionLabel,
    'block_type': type.db,
    'tier': tier.toDb,
    'body': body,
    'answers': answers,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentBlock && other.blockId == blockId;

  @override
  int get hashCode => blockId.hashCode;
}

/// One part of a question: "A." and its question, a choice "a." to pick,
/// or a verse to explain.
@immutable
class BlockPart {
  const BlockPart({required this.text, this.label, this.respond});

  factory BlockPart.fromMap(Map<String, dynamic> map) => BlockPart(
    label: map['label'] as String?,
    text: '${map['text'] ?? ''}',
    respond: map['respond'] as String?,
  );

  final String? label;
  final String text;
  final String? respond;
}

/// A lettered section of a lesson: its title, when the publication has
/// one, and the blocks inside it in order.
@immutable
class LessonSection {
  const LessonSection({required this.label, required this.blocks, this.title});

  final String label;
  final String? title;
  final List<ContentBlock> blocks;

  List<String> get scriptureRefs => [
    for (final b in blocks)
      if (b.type == BlockType.scriptureReferences) ...b.refs,
  ];
}

/// One lesson as the reader shows it: the blocks the database returned for
/// this reader, grouped for display. Derived only; nothing here decides
/// access.
@immutable
class LessonContent {
  const LessonContent({required this.lessonId, required this.blocks});

  final String lessonId;

  /// In publication order.
  final List<ContentBlock> blocks;

  /// The lesson as a Disciple reads it: the Disciple tier, no answers. For
  /// someone who is both a Disciple and a Discipler, reading their own
  /// lesson (ADR-021); the database still decides what they may read.
  LessonContent get discipleView => LessonContent(
    lessonId: lessonId,
    blocks: [
      for (final b in blocks)
        if (b.tier == ContentTier.disciple)
          ContentBlock(
            blockId: b.blockId,
            lessonId: b.lessonId,
            ordinal: b.ordinal,
            sectionLabel: b.sectionLabel,
            type: b.type,
            tier: b.tier,
            body: b.body,
          ),
    ],
  );

  /// Blocks with blanks the book answers, which a check can compare.
  List<ContentBlock> get checkable => [
    for (final b in blocks)
      if (b.tier == ContentTier.disciple &&
          b.blankCount > 0 &&
          b.type != BlockType.verseWriting &&
          b.type != BlockType.figure)
        b,
  ];

  /// Whether this is the faithful lesson (ADR-019 decision 12) rather than
  /// its identifying metadata only.
  bool get isFull => blocks.any(
    (b) => b.type != BlockType.unknown && !BlockType.metadata.contains(b.type),
  );

  String? get theme => _first(BlockType.lessonTheme)?.text;
  List<String> get topics => _first(BlockType.topicList)?.items ?? const [];

  /// Sections in order of first appearance, Disciple tier only.
  List<LessonSection> get sections {
    final order = <String>[];
    final byLabel = <String, List<ContentBlock>>{};
    for (final b in blocks) {
      final label = b.sectionLabel;
      if (label == null || b.tier != ContentTier.disciple) continue;
      if (!byLabel.containsKey(label)) order.add(label);
      byLabel.putIfAbsent(label, () => []).add(b);
    }
    return [
      for (final label in order)
        LessonSection(
          label: label,
          title: byLabel[label]!
              .where((b) => b.type == BlockType.sectionHeading)
              .map((b) => b.title)
              .firstWhere((t) => t != null, orElse: () => null),
          blocks: byLabel[label]!,
        ),
    ];
  }

  /// Discipler-tier blocks; empty for a Disciple, whose read never
  /// includes them.
  List<ContentBlock> get disciplerBlocks => [
    for (final b in blocks)
      if (b.tier == ContentTier.discipler && b.type != BlockType.unknown) b,
  ];

  bool get hasDisciplerTier => disciplerBlocks.isNotEmpty;

  /// Whether the read carries the book's answers: a Discipler's read, even
  /// of a lesson without Discipler-only blocks.
  bool get hasAnswers =>
      hasDisciplerTier || blocks.any((b) => b.answers != null);

  ContentBlock? _first(BlockType type) {
    for (final b in blocks) {
      if (b.type == type) return b;
    }
    return null;
  }
}

/// One row of `list_lesson_access()`: a lesson and what the reader may read
/// of it, in a given context.
@immutable
class LessonAccess {
  const LessonAccess({
    required this.lessonId,
    required this.number,
    required this.title,
    required this.discipleTier,
    required this.disciplerTier,
    this.theme,
  });

  factory LessonAccess.fromMap(Map<String, dynamic> map) => LessonAccess(
    lessonId: map['lesson_id'] as String,
    number: map['lesson_number'] as int,
    title: map['title'] as String,
    theme: map['theme'] as String?,
    discipleTier: map['disciple_tier'] as bool,
    disciplerTier: map['discipler_tier'] as bool,
  );

  final String lessonId;
  final int number;
  final String title;
  final String? theme;
  final bool discipleTier;
  final bool disciplerTier;

  bool get isOpen => discipleTier || disciplerTier;

  Map<String, dynamic> toMap() => {
    'lesson_id': lessonId,
    'lesson_number': number,
    'title': title,
    'theme': theme,
    'disciple_tier': discipleTier,
    'discipler_tier': disciplerTier,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonAccess &&
          other.lessonId == lessonId &&
          other.discipleTier == discipleTier &&
          other.disciplerTier == disciplerTier &&
          other.title == title &&
          other.theme == theme;

  @override
  int get hashCode =>
      Object.hash(lessonId, discipleTier, disciplerTier, title, theme);
}

/// The device copy of everything the person may read (ADR-019 decision 7):
/// their own lesson list and every block `get_my_readable_content()`
/// returned. Display data only; replaced, never merged, on each refresh, so
/// it is pruned to the current scope.
@immutable
class ReadableContent {
  const ReadableContent({
    required this.userId,
    required this.savedAt,
    required this.lessons,
    required this.blocks,
  });

  static const version = 1;

  final String userId;
  final DateTime savedAt;

  /// The person's own lesson list (no context).
  final List<LessonAccess> lessons;
  final List<ContentBlock> blocks;

  /// The cached blocks of one lesson, or null when none were synced.
  LessonContent? lesson(String lessonId) {
    final rows = [
      for (final b in blocks)
        if (b.lessonId == lessonId) b,
    ]..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return rows.isEmpty
        ? null
        : LessonContent(lessonId: lessonId, blocks: rows);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'user_id': userId,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'lessons': [for (final l in lessons) l.toMap()],
    'blocks': [for (final b in blocks) b.toMap()],
  };

  /// Null for a copy of another version, or one that cannot be read.
  static ReadableContent? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != version) return null;
      return ReadableContent(
        userId: json['user_id'] as String,
        savedAt: DateTime.parse(json['saved_at'] as String),
        lessons: [
          for (final l in json['lessons'] as List)
            LessonAccess.fromMap((l as Map).cast<String, dynamic>()),
        ],
        blocks: [
          for (final b in json['blocks'] as List)
            ContentBlock.fromMap((b as Map).cast<String, dynamic>()),
        ],
      );
    } on Object {
      return null;
    }
  }
}
