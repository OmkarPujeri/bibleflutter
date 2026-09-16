import 'dart:convert';
import 'dart:math';

import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/mood/application/mood_controller.dart';
import 'package:bible_connect/features/mood/data/mood_history_store.dart';
import 'package:bible_connect/features/mood/data/mood_repository.dart';
import 'package:bible_connect/features/mood/domain/mood_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bible/bible_repository_test.dart' show FakeBundle, fixtureBundle;

/// In-memory mood assets matching the real format, tiny enough to reason about.
FakeBundle moodFixture() => FakeBundle({
      'assets/bible/index.json': fixtureBundle()
          .assets['assets/bible/index.json']!,
      'assets/bible/books/GEN.json':
          fixtureBundle().assets['assets/bible/books/GEN.json']!,
      'assets/bible/books/JHN.json':
          fixtureBundle().assets['assets/bible/books/JHN.json']!,
      'assets/mood/mood_questions.json': '''
      {
        "unpleasant": [
          {"id": "u_1", "question": "Which describes you?",
           "options": [
             {"text": "Anxious.", "category": "anxiety"},
             {"text": "Discouraged.", "category": "discouragement"},
             {"text": "Hurt.", "category": "hurt"}
           ]}
        ]
      }
      ''',
      'assets/mood/mood_verse_mapping.json': '''
      {
        "unpleasant": {
          "anxiety": ["GEN.1.1"],
          "discouragement": ["GEN.1.2"],
          "hurt": ["GEN.1.3"]
        },
        "veryUnpleasant": {
          "despair": ["JHN.1.1"],
          "anger": [],
          "grief": []
        }
      }
      ''',
    });

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(moodFixture())),
      moodRepositoryProvider.overrideWithValue(MoodRepository(moodFixture())),
      moodRngProvider.overrideWithValue(Random(42)),
    ]);
    container.read(moodControllerProvider);
  });

  tearDown(() => container.dispose());

  test('full happy path: intensity -> question -> option -> verse', () async {
    final c = container.read(moodControllerProvider.notifier);

    c.setIntensity(4.0); // unpleasant
    expect(container.read(moodControllerProvider).selectedLevel,
        MoodLevel.unpleasant);

    await c.nextStep();
    var s = container.read(moodControllerProvider);
    expect(s.step, 1);
    expect(s.followUpQuestion!.options.length, 3);

    c.selectOption(0); // "Anxious." -> category anxiety
    await c.nextStep();
    expect(container.read(moodControllerProvider).step, 2);

    await c.submit();
    s = container.read(moodControllerProvider);
    expect(s.isLoading, false);
    expect(s.recommendedVerse, isNotNull);
    expect(s.recommendedVerse!.osis, 'GEN.1.1');
  });

  test('submit writes today record to history', () async {
    final c = container.read(moodControllerProvider.notifier);
    c.setIntensity(4.0);
    await c.nextStep();
    c.selectOption(1); // discouragement
    await c.nextStep();
    await c.submit();

    expect(
      container.read(moodHistoryStoreProvider).today()!.osis,
      'GEN.1.2',
    );
  });

  test('back from step 1 clears the selected option (GitaConnect rule)',
      () async {
    final c = container.read(moodControllerProvider.notifier);
    c.setIntensity(4.0);
    await c.nextStep();
    c.selectOption(2);
    c.back();
    var s = container.read(moodControllerProvider);
    expect(s.step, 0);
    expect(s.selectedOption, isNull);
  });

  test('unknown category falls back to a verse from the whole level',
      () async {
    final c = container.read(moodControllerProvider.notifier);
    // veryUnpleasant in the fixture only has despair: [JHN.1.1]; picking a
    // category with an empty list exercises the fallback path.
    c.setIntensity(1.0); // veryUnpleasant
    await c.nextStep();
    // Fixture has questions only for "unpleasant", so simulate directly:
    final verse = await c.pickVerseForTest('anger');
    expect(verse, isNotNull);
  });

  test('reset returns to a fresh wizard', () async {
    final c = container.read(moodControllerProvider.notifier);
    c.setIntensity(4.0);
    await c.nextStep();
    c.reset();
    final s = container.read(moodControllerProvider);
    expect(s.step, 0);
    expect(s.selectedLevel, isNull);
    expect(s.recommendedVerse, isNull);
  });

  test('selectOption ignores negative and out-of-range indices', () async {
    final c = container.read(moodControllerProvider.notifier);
    c.setIntensity(4.0);
    await c.nextStep();
    c.selectOption(-1);
    c.selectOption(99);
    final s = container.read(moodControllerProvider);
    expect(s.selectedOption, isNull);
    expect(s.selectedCategory, isNull);
  });

  test('submit is a no-op while another submit is in flight', () async {
    final c = container.read(moodControllerProvider.notifier);
    c.setIntensity(4.0);
    await c.nextStep();
    c.selectOption(0);
    await c.nextStep();

    // Second call (double-tap) must return early: only one record is written.
    final first = c.submit();
    final second = c.submit();
    await Future.wait([first, second]);

    expect(container.read(moodHistoryStoreProvider).all().length, 1);
  });

  test('startNewCheckIn overrides today; submit clears the override',
      () async {
    SharedPreferences.setMockInitialValues({
      'mood.history': jsonEncode([
        {
          'date': DateTime.now().toIso8601String(),
          'osis': 'GEN.1.2',
          'level': MoodLevel.unpleasant.index,
        },
      ]),
    });
    final todayContainer = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance()),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(moodFixture())),
      moodRepositoryProvider.overrideWithValue(MoodRepository(moodFixture())),
      moodRngProvider.overrideWithValue(Random(42)),
    ]);
    addTearDown(todayContainer.dispose);

    final c = todayContainer.read(moodControllerProvider.notifier);
    expect(todayContainer.read(todaysMoodProvider), isNotNull);

    // Despite today's record, the wizard must show at step 0.
    c.startNewCheckIn();
    var s = todayContainer.read(moodControllerProvider);
    expect(s.step, 0);
    expect(s.overrideToday, isTrue);
    expect(s.selectedLevel, isNull);

    // Walk the wizard and submit — the override clears and the history
    // providers see the new record.
    c.setIntensity(4.0);
    await c.nextStep();
    c.selectOption(0);
    await c.nextStep();
    await c.submit();

    s = todayContainer.read(moodControllerProvider);
    expect(s.recommendedVerse, isNotNull);
    expect(s.overrideToday, isFalse);
    expect(todayContainer.read(moodHistoryStoreProvider).all().length, 2);
    expect(todayContainer.read(moodHistoryProvider).length, 2);
  });
}
