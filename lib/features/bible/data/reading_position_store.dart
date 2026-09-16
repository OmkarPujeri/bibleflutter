import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/debug_report.dart';
import '../../../core/settings/settings_controller.dart';
import '../domain/bible_models.dart';

const _kPositionKey = 'reader.position';

class ReadingPositionStore {
  ReadingPositionStore(this._prefs);

  final SharedPreferences _prefs;

  /// Corrupt/missing data reads as null — the reader then opens at GEN 1:1
  /// (GitaConnect's LastReadNotifier try/catch pattern).
  VerseRef? load() {
    final raw = _prefs.getString(_kPositionKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return VerseRef(
        bookId: m['bookId'] as String,
        chapter: m['chapter'] as int,
        verse: m['verse'] as int,
      );
    } catch (e, st) {
      reportCaughtError(e, st, context: 'reading the saved position');
      return null;
    }
  }

  Future<void> save(VerseRef ref) => _prefs.setString(
        _kPositionKey,
        jsonEncode({
          'bookId': ref.bookId,
          'chapter': ref.chapter,
          'verse': ref.verse,
        }),
      );
}

final readingPositionStoreProvider = Provider<ReadingPositionStore>(
  (ref) => ReadingPositionStore(ref.watch(sharedPreferencesProvider)),
);

/// Reactive saved position — the reader watches this on first open.
class LastReadNotifier extends Notifier<VerseRef?> {
  @override
  VerseRef? build() =>
      ref.watch(readingPositionStoreProvider).load();

  Future<void> save(VerseRef ref) async {
    // `this.ref` because the [VerseRef] parameter shadows the Notifier's Ref.
    await this.ref.read(readingPositionStoreProvider).save(ref);
    state = ref;
  }
}

final lastReadProvider =
    NotifierProvider<LastReadNotifier, VerseRef?>(LastReadNotifier.new);
