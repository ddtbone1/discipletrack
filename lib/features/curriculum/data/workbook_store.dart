import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Disciple's written answers, on this device only (ADR-021), one entry
/// per person and lesson. Kept across sign-out, because they belong to the
/// person who wrote them, keyed by that person so nobody else signing in
/// on the device sees them.
class WorkbookStore {
  static String _key(String userId, String lessonId) =>
      'workbook.v1.$userId.$lessonId';

  Future<Map<String, Map<String, String>>> read(
    String userId,
    String lessonId,
  ) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(userId, lessonId),
    );
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: (e.value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as String),
          ),
      };
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> write(
    String userId,
    String lessonId,
    Map<String, Map<String, String>> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(_key(userId, lessonId));
    } else {
      await prefs.setString(_key(userId, lessonId), jsonEncode(entries));
    }
  }
}

final workbookStoreProvider = Provider<WorkbookStore>((ref) => WorkbookStore());
