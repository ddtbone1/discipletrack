import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../ministry/domain/d_group_member.dart';
import '../../offline/application/offline_providers.dart';
import '../data/curriculum_repository.dart';
import '../data/workbook_store.dart';
import '../domain/lesson_content.dart';
import '../domain/workbook.dart';

const _offlineNoCopy = CurriculumFailure(
  "You're offline, and this lesson hasn't been downloaded to this device "
  'yet. Connect once to download your lessons.',
  code: DbFailureCode.network,
);

/// Runs [live]; offline, answers from the device copy instead (ADR-019
/// decision 7). A refusal from the database is a real answer and is never
/// replaced with cached content.
Future<T> _liveOrCopy<T>(
  Ref ref, {
  required Future<T> Function() live,
  required T? Function(ReadableContent copy) fromCopy,
}) async {
  final userId = ref.read(currentUserIdProvider);
  final store = ref.read(curriculumCacheStoreProvider);

  Future<T> fromDevice() async {
    final copy = userId == null ? null : await store.read(userId);
    final value = copy == null ? null : fromCopy(copy);
    if (value == null) throw _offlineNoCopy;
    return value;
  }

  if (ref.read(isOfflineProvider)) return fromDevice();
  try {
    final value = await live().timeout(liveTimeout);
    ref.read(isOfflineProvider.notifier).markOnline();
    return value;
  } catch (error) {
    if (!isNetworkFailure(error) && error is! TimeoutException) rethrow;
    ref.read(isOfflineProvider.notifier).markOffline();
    return fromDevice();
  }
}

/// A refusal from the database is final, so it is shown at once instead of
/// after automatic retries. Everything else keeps the default policy.
Duration? _retry(int count, Object error) =>
    error is CurriculumFailure && error.isRefused
    ? null
    : ProviderContainer.defaultRetry(count, error);

/// An ACTIVE membership in an ACTIVE church (ADR-022): nothing of the
/// curriculum is read, or kept on the device, otherwise.
bool _isActive(Ref ref) => ref.watch(hasChurchAccessProvider);

/// Everything the person may read now, refreshed from the server and saved
/// as the device copy. Each save replaces the last, so content the person
/// may no longer read leaves the device on the next refresh.
final myReadableContentProvider = FutureProvider<ReadableContent?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final store = ref.read(curriculumCacheStoreProvider);
  if (!_isActive(ref)) {
    // A church known to be SUSPENDED or ARCHIVED keeps nothing of its
    // curriculum on the device (ADR-022 decision 14). Only on a live answer:
    // offline, the church row may itself be the saved one.
    final church = ref.watch(myChurchProvider).value;
    if (church != null && !church.isAvailable && !ref.read(isOfflineProvider)) {
      await store.clear(userId);
    }
    return null;
  }
  // The Disciple contexts the reader may read in (ADR-023): the Disciples
  // paired with them and, for a Leader, every Disciple of the group. The
  // database decides what each opens; refused contexts are left out.
  final ministry = ref.watch(myMinistryContextProvider).value;
  final contextIds = <String>{
    if (ministry != null) ...[
      for (final d in ministry.myDisciples) d.churchMembershipId,
      if (ministry.isLeader)
        for (final e in ministry.roster)
          if (e.responsibility == DGroupResponsibility.disciple && !e.isMe)
            e.churchMembershipId,
    ],
  };
  return _liveOrCopy(
    ref,
    live: () async {
      final content = await ref
          .read(curriculumRepositoryProvider)
          .fetchMyReadableContent(userId, contextIds: contextIds);
      await store.write(content);
      return content;
    },
    fromCopy: (copy) => copy,
  );
});

/// Watched by the app root so the device copy is downloaded once a session
/// is active, without anyone having to open a lesson first (ADR-010
/// decision 8: no per-lesson download step).
final curriculumSyncProvider = Provider<void>((ref) {
  if (ref.watch(isOfflineProvider)) return;
  ref.watch(myReadableContentProvider);
});

/// The lesson list with what the reader may open, in the context of a
/// person ([forMembershipId]) or of the reader themselves (null).
final lessonAccessProvider = FutureProvider.family<List<LessonAccess>, String?>(
  (ref, forMembershipId) async {
    if (!_isActive(ref)) return const [];
    return _liveOrCopy(
      ref,
      live: () => ref
          .read(curriculumRepositoryProvider)
          .fetchLessonAccess(forMembershipId: forMembershipId),
      // Offline, the saved access of that context. A context that was not
      // saved opens nothing: the copy's blocks belong to every context
      // together, so they never decide access on their own (ADR-023).
      fromCopy: (copy) =>
          copy.accessFor(forMembershipId) ??
          [
            for (final l in copy.lessons)
              LessonAccess(
                lessonId: l.lessonId,
                number: l.number,
                title: l.title,
                discipleTier: false,
                disciplerTier: false,
              ),
          ],
    );
  },
  retry: _retry,
);

/// Which lesson to read, and in whose context.
typedef LessonKey = ({String lessonId, String? forMembershipId});

/// One lesson's content for the reader.
final lessonContentProvider = FutureProvider.family<LessonContent, LessonKey>((
  ref,
  key,
) async {
  return _liveOrCopy(
    ref,
    live: () => ref
        .read(curriculumRepositoryProvider)
        .fetchLessonContent(key.lessonId, forMembershipId: key.forMembershipId),
    // Only what this context may read, from the copy of every context.
    fromCopy: (copy) => copy.lessonIn(key.lessonId, key.forMembershipId),
  );
}, retry: _retry);

/// Each lesson's cover photo by lesson id (decoded JPEG bytes), for the
/// lesson list. From the server when it answers, else from the device.
final lessonCoversProvider = FutureProvider<Map<String, Uint8List>>((
  ref,
) async {
  if (!_isActive(ref)) return const {};
  final store = ref.read(curriculumCacheStoreProvider);
  Map<String, String>? raw;
  try {
    raw = await ref.read(curriculumRepositoryProvider).fetchCovers();
    await store.writeCovers(raw);
  } on CurriculumFailure {
    raw = await store.readCovers();
  }
  return {
    for (final e in (raw ?? const <String, String>{}).entries)
      e.key: base64Decode(e.value),
  };
});

/// The reader's own written answers for one lesson, on this device
/// (ADR-021). Null when signed out.
final workbookProvider = FutureProvider.autoDispose.family<Workbook?, String>((
  ref,
  lessonId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final store = ref.read(workbookStoreProvider);
  final workbook = Workbook(
    entries: await store.read(userId, lessonId),
    onSave: (entries) => store.write(userId, lessonId, entries),
  );
  ref.onDispose(workbook.dispose);
  return workbook;
});
