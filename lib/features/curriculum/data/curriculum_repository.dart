import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/lesson_content.dart';

/// A failed curriculum read, with a message fit to show a person.
class CurriculumFailure implements Exception, NetworkAwareFailure {
  const CurriculumFailure(this.message, {this.code = DbFailureCode.unknown});

  final String message;
  final DbFailureCode code;

  @override
  bool get isNetwork => code == DbFailureCode.network;

  bool get isRefused => code == DbFailureCode.forbidden;

  @override
  String toString() => message;
}

/// Lesson content reads (Migration 017). Every read is a controlled
/// operation that applies ADR-019's tiers and progression gate in the
/// database; the client never filters content itself.
class CurriculumRepository {
  CurriculumRepository(this._client);

  final SupabaseClient _client;

  /// `list_lesson_access()`: every lesson with what the caller may read, in
  /// the context of [forMembershipId] (or themselves).
  Future<List<LessonAccess>> fetchLessonAccess({String? forMembershipId}) =>
      _guard('Could not load the lessons.', () async {
        final rows = await _client.rpc<List<dynamic>>(
          'list_lesson_access',
          params: {'p_for_membership_id': forMembershipId},
        );
        return [
          for (final r in rows) LessonAccess.fromMap(r as Map<String, dynamic>),
        ];
      });

  /// `get_lesson_content()`: the blocks of one lesson the caller may read.
  Future<LessonContent> fetchLessonContent(
    String lessonId, {
    String? forMembershipId,
  }) => _guard('Could not load this lesson.', () async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_lesson_content',
      params: {'p_lesson_id': lessonId, 'p_for_membership_id': forMembershipId},
    );
    return LessonContent(
      lessonId: lessonId,
      blocks: [
        for (final r in rows)
          ContentBlock.fromMap(r as Map<String, dynamic>, lessonId: lessonId),
      ],
    );
  });

  /// `get_lesson_covers()`: each lesson's cover photo (base64 JPEG), for
  /// the lesson list. Readable by every active member.
  Future<Map<String, String>> fetchCovers() =>
      _guard('Could not load the lesson covers.', () async {
        final rows = await _client.rpc<List<dynamic>>('get_lesson_covers');
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['lesson_id'] as String: r['image'] as String,
        };
      });

  /// `get_my_readable_content()` plus the caller's own lesson list: the
  /// device copy (ADR-019 decision 7).
  Future<ReadableContent> fetchMyReadableContent(String userId) => _guard(
    'Could not load your lessons.',
    () async {
      final rows = await _client.rpc<List<dynamic>>('get_my_readable_content');
      final lessons = await fetchLessonAccess();
      return ReadableContent(
        userId: userId,
        savedAt: DateTime.now().toUtc(),
        lessons: lessons,
        blocks: [
          for (final r in rows) ContentBlock.fromMap(r as Map<String, dynamic>),
        ],
      );
    },
  );

  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final code = PostgrestFailure.codeOf(e);
      throw CurriculumFailure(
        code == DbFailureCode.forbidden
            ? "This lesson isn't open to you."
            : PostgrestFailure.friendlyMessage(e, fallback),
        code: code,
      );
    } on CurriculumFailure {
      rethrow;
    } on Exception {
      throw const CurriculumFailure(
        PostgrestFailure.networkMessage,
        code: DbFailureCode.network,
      );
    }
  }
}

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(ref.watch(supabaseClientProvider));
});

/// The device copy of readable lesson content, one per signed-in user, in
/// `shared_preferences`, next to the Slice 4 snapshot. Disabled on the web,
/// like the snapshot. Each write replaces the previous copy, which is how it
/// is pruned to the current scope; sign-out clears every copy.
class CurriculumCacheStore {
  CurriculumCacheStore({bool? enabled}) : enabled = enabled ?? !kIsWeb;

  final bool enabled;

  static const _prefix = 'curriculum_cache.';

  Future<ReadableContent?> read(String userId) async {
    if (!enabled) return null;
    final raw = (await SharedPreferences.getInstance()).getString(
      '$_prefix$userId',
    );
    if (raw == null) return null;
    try {
      final copy = ReadableContent.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      return copy?.userId == userId ? copy : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(ReadableContent content) async {
    if (!enabled) return;
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix${content.userId}',
      jsonEncode(content.toJson()),
    );
  }

  /// The covers, kept beside the content copy so the lesson list keeps its
  /// pictures offline.
  static const _covers = 'curriculum_covers';

  Future<Map<String, String>?> readCovers() async {
    if (!enabled) return null;
    final raw = (await SharedPreferences.getInstance()).getString(_covers);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } on Object {
      return null;
    }
  }

  Future<void> writeCovers(Map<String, String> covers) async {
    if (!enabled) return;
    await (await SharedPreferences.getInstance()).setString(
      _covers,
      jsonEncode(covers),
    );
  }

  Future<void> clearAll() async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

final curriculumCacheStoreProvider = Provider<CurriculumCacheStore>(
  (ref) => CurriculumCacheStore(),
);
