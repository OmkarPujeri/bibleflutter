import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider lives in the legacy library as of Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/debug_report.dart';
import '../../../core/settings/settings_controller.dart';
import '../../bible/domain/bible_models.dart';
import '../domain/mood_models.dart';

const _kHistoryKey = 'mood.history';

class MoodHistoryStore {
  MoodHistoryStore(this._prefs);

  final SharedPreferences _prefs;

  List<MoodRecord> all() {
    final raw = _prefs.getString(_kHistoryKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        // Skip records whose osis doesn't parse (corrupt/persisted garbage)
        // instead of throwing — the rest of the history stays usable.
        for (final e in list.cast<Map<String, dynamic>>())
          if (VerseRef.parse((e['osis'] as String?) ?? '') != null)
            MoodRecord(
              date: DateTime.parse(e['date'] as String),
              osis: e['osis'] as String,
              level: MoodLevel.values[e['level'] as int],
            ),
      ];
    } catch (e, st) {
      reportCaughtError(e, st, context: 'reading mood history');
      return [];
    }
  }

  /// The LATEST same-day record (a second check-in supersedes the first);
  /// null when nothing was recorded today.
  MoodRecord? today() {
    final now = DateTime.now();
    MoodRecord? found;
    for (final record in all()) {
      if (record.date.year == now.year &&
          record.date.month == now.month &&
          record.date.day == now.day) {
        found = record; // records are chronological — keep the last match
      }
    }
    return found;
  }

  Future<void> add(MoodRecord record) async {
    final records = all()..add(record);
    await _prefs.setString(
      _kHistoryKey,
      jsonEncode([
        for (final r in records)
          {
            'date': r.date.toIso8601String(),
            'osis': r.osis,
            'level': r.level.index,
          },
      ]),
    );
  }

  Future<void> clear() => _prefs.remove(_kHistoryKey);
}

final moodHistoryStoreProvider = Provider<MoodHistoryStore>(
  (ref) => MoodHistoryStore(ref.watch(sharedPreferencesProvider)),
);

final todaysMoodProvider = Provider<MoodRecord?>(
  (ref) => ref.watch(moodHistoryStoreProvider).today(),
);

/// Reactive full history — chronological (newest last); the UI displays it
/// reversed. [MoodController.submit] refreshes it after each check-in, so
/// the list updates without an app restart.
// StateProvider lives in the legacy library as of Riverpod 3.
final moodHistoryProvider = StateProvider<List<MoodRecord>>(
  (ref) => ref.watch(moodHistoryStoreProvider).all(),
);
