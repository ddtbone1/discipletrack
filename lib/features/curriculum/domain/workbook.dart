import 'dart:async';

import 'package:flutter/foundation.dart';

/// One checked blank: right or not, and the book's answer.
@immutable
class BlankResult {
  const BlankResult({
    required this.blank,
    required this.correct,
    required this.answer,
  });

  final int blank;
  final bool correct;
  final String answer;
}

/// What a Disciple has written in one lesson: per block, per place
/// ("b0" the first blank, "f0" the first writing field, "v" the verse,
/// "s0" the first self-check row).
///
/// Kept on this device only (ADR-021). It is display data for the person
/// who wrote it: nothing reads it on the server, and it never counts as
/// progress or completion.
class Workbook extends ChangeNotifier {
  Workbook({
    required Map<String, Map<String, String>> entries,
    required this.onSave,
    this.saveDelay = const Duration(milliseconds: 400),
  }) : _entries = {
         for (final e in entries.entries) e.key: {...e.value},
       };

  final Map<String, Map<String, String>> _entries;
  final Future<void> Function(Map<String, Map<String, String>>) onSave;
  final Duration saveDelay;
  Timer? _timer;

  String? valueOf(String blockId, String place) => _entries[blockId]?[place];

  Map<String, Map<String, String>> get entries => {
    for (final e in _entries.entries) e.key: Map.unmodifiable(e.value),
  };

  /// The last check of the blanks, by block and blank: right or not, and
  /// the book's answer. Held for this reading only, never saved.
  final Map<String, Map<int, BlankResult>> _checked = {};

  BlankResult? resultOf(String blockId, int blank) => _checked[blockId]?[blank];

  bool get hasResults => _checked.isNotEmpty;

  void showResults(Iterable<({String blockId, BlankResult result})> results) {
    _checked.clear();
    for (final r in results) {
      _checked.putIfAbsent(r.blockId, () => {})[r.result.blank] = r.result;
    }
    notifyListeners();
  }

  /// What was written in [count] blanks of a block, in order.
  List<String> blanksOf(String blockId, int count) => [
    for (var i = 0; i < count; i++) valueOf(blockId, 'b$i') ?? '',
  ];

  void write(String blockId, String place, String value) {
    // A changed blank is no longer checked.
    if (place.startsWith('b')) {
      _checked[blockId]?.remove(int.tryParse(place.substring(1)));
    }
    final block = _entries.putIfAbsent(blockId, () => {});
    if (value.isEmpty) {
      block.remove(place);
      if (block.isEmpty) _entries.remove(blockId);
    } else {
      block[place] = value;
    }
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(saveDelay, flush);
  }

  /// Saves now; called when the lesson closes.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await onSave(entries);
  }

  @override
  void dispose() {
    if (_timer != null) unawaited(flush());
    super.dispose();
  }
}
