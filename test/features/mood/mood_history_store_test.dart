import 'dart:convert';

import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/mood/data/mood_history_store.dart';
import 'package:bible_connect/features/mood/domain/mood_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('add persists and today() returns the same-day record', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);

    final store = container.read(moodHistoryStoreProvider);
    expect(store.today(), isNull);

    await store.add(MoodRecord(
      date: DateTime.now(),
      osis: 'PSA.23.4',
      level: MoodLevel.unpleasant,
    ));

    expect(store.today()!.osis, 'PSA.23.4');
    expect(store.all().length, 1);
  });

  test('today() returns the LATEST same-day record', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);

    final store = container.read(moodHistoryStoreProvider);
    final now = DateTime.now();
    await store.add(MoodRecord(
      date: DateTime(now.year, now.month, now.day, 8),
      osis: 'GEN.1.1',
      level: MoodLevel.unpleasant,
    ));
    await store.add(MoodRecord(
      date: DateTime(now.year, now.month, now.day, 22),
      osis: 'JHN.3.16',
      level: MoodLevel.pleasant,
    ));

    expect(store.today()!.osis, 'JHN.3.16');
    expect(store.all().length, 2);
  });

  test('old records are kept but today() is null', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);

    await container.read(moodHistoryStoreProvider).add(MoodRecord(
      date: DateTime.now().subtract(const Duration(days: 2)),
      osis: 'JHN.3.16',
      level: MoodLevel.pleasant,
    ));

    expect(container.read(moodHistoryStoreProvider).today(), isNull);
    expect(container.read(moodHistoryStoreProvider).all().length, 1);
  });

  test('corrupt history JSON loads as empty, never throws', () async {
    SharedPreferences.setMockInitialValues({
      'mood.history': 'not json at all',
    });
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(moodHistoryStoreProvider).all(), isEmpty);
  });

  test('all() skips records whose osis does not parse', () async {
    // A corrupt record (bad osis) must not poison the rest of the history —
    // and must never crash the tab that renders today's record.
    SharedPreferences.setMockInitialValues({
      'mood.history': jsonEncode([
        {
          'date': DateTime.now().toIso8601String(),
          'osis': 'GEN.1.2',
          'level': MoodLevel.unpleasant.index,
        },
        {
          'date': DateTime.now().toIso8601String(),
          'osis': 'garbage',
          'level': MoodLevel.pleasant.index,
        },
        {
          'date': DateTime.now().toIso8601String(),
          'osis': 'GEN.0.1', // unparsable: chapter < 1
          'level': MoodLevel.pleasant.index,
        },
      ]),
    });
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);

    final store = container.read(moodHistoryStoreProvider);
    expect(store.all().length, 1);
    expect(store.all().single.osis, 'GEN.1.2');
    expect(store.today()!.osis, 'GEN.1.2');
  });
}
