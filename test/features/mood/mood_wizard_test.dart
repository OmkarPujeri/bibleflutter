import 'dart:convert';
import 'dart:math';

import 'package:bible_connect/core/router/app_shell.dart';
import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/bible/application/reader_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:bible_connect/features/mood/application/mood_controller.dart';
import 'package:bible_connect/features/mood/data/mood_repository.dart';
import 'package:bible_connect/features/mood/domain/mood_models.dart';
import 'package:bible_connect/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mood_controller_test.dart' show moodFixture;

ProviderContainer _moodAppContainer(SharedPreferences prefs) {
  final bundle = moodFixture();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    bibleRepositoryProvider.overrideWithValue(BibleRepository(bundle)),
    moodRepositoryProvider.overrideWithValue(MoodRepository(bundle)),
    moodRngProvider.overrideWithValue(Random(42)),
  ]);
}

/// BibleRepository decodes assets via `compute` (Isolate.run); its reply is
/// only delivered through the real event loop, i.e. inside tester.runAsync —
/// under the widget-test fake-async zone the future would stay pending and
/// pumpAndSettle would never settle. Pre-warm the reader boot and the GEN 1
/// cache (the fixture's recommended verse lives there).
Future<void> _prewarm(WidgetTester tester, ProviderContainer container) =>
    tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
      await container
          .read(bibleRepositoryProvider)
          .findVerse(const VerseRef(bookId: 'GEN', chapter: 1, verse: 1));
    });

void main() {
  testWidgets('wizard walks through all three steps to a verse',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = _moodAppContainer(prefs);
    addTearDown(container.dispose);

    await _prewarm(tester, container);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    // Tab 1 = Mood.
    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();

    // Step 0: drag the slider into the "Unpleasant" band (snapped scores 3
    // or 4 — the only level the fixture has questions for). The drag lands
    // anywhere in a ~150px window, so it is not pixel-fragile; the label
    // assertion fails loudly if the mapping ever drifts.
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pump();
    expect(find.text('Unpleasant'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 1: question appears; select the first option.
    expect(find.text('Which describes you?'), findsOneWidget);
    await tester.tap(find.text('Anxious.'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: submit.
    await tester.tap(find.text('Find my verse'));
    await tester.pumpAndSettle();

    // Result — deterministic: the fixture maps unpleasant/anxiety to GEN.1.1
    // (a single verse, so the seeded RNG has nothing to choose between).
    // The reference is shown human-readable (formatRef), not as OSIS.
    expect(find.text('For this moment'), findsOneWidget);
    expect(find.text('Open in reader'), findsOneWidget);
    expect(find.textContaining('Genesis 1:1'), findsOneWidget);
    expect(find.textContaining('In the beginning God created'), findsOneWidget);

    // Open in reader switches to the Bible tab and focuses the verse.
    await tester.tap(find.text('Open in reader'));
    await tester.pumpAndSettle();
    expect(container.read(currentTabProvider), 0);
    expect(find.text('Genesis 1'), findsOneWidget);
    expect(find.text('Genesis 1:1'), findsOneWidget);
  });

  testWidgets("today's saved mood shows instead of the wizard on reopen",
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'mood.history': jsonEncode([
        {
          'date': DateTime.now().toIso8601String(),
          'osis': 'GEN.1.2',
          'level': MoodLevel.unpleasant.index,
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = _moodAppContainer(prefs);
    addTearDown(container.dispose);

    await _prewarm(tester, container);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();

    expect(find.text('For this moment'), findsOneWidget);
    expect(find.textContaining('Genesis 1:2'), findsOneWidget);
    expect(find.textContaining('formless and empty'), findsOneWidget);
    expect(find.text('How are you feeling right now?'), findsNothing);
  });

  testWidgets(
      'thoughts and slider survive back-navigation to step 0',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = _moodAppContainer(prefs);
    addTearDown(container.dispose);

    await _prewarm(tester, container);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();

    // Step 0 -> Unpleasant.
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 1 -> option -> step 2, and type some thoughts.
    await tester.tap(find.text('Anxious.'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Lord, I feel anxious about work.');
    await tester.pump();

    // Back to step 1, then back to step 0.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    // The slider must be restored from the chosen level (unpleasant ->
    // representative score 4), not reset to the default 5 (neutral).
    expect(find.text('Unpleasant'), findsOneWidget);
    expect(find.text('Neutral'), findsNothing);

    // Walk forward again; the typed thoughts must still be in the field.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Which describes you?'), findsOneWidget);
    await tester.tap(find.text('Anxious.'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Lord, I feel anxious about work.'), findsOneWidget);
  });

  testWidgets(
      'Start over works after a same-day check-in and history lists it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = _moodAppContainer(prefs);
    addTearDown(container.dispose);

    await _prewarm(tester, container);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();

    // Complete a check-in (unpleasant/anxiety -> GEN.1.1).
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anxious.'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find my verse'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Genesis 1:1'), findsOneWidget);

    // "Start over" must show the wizard (override today), not today's result.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling right now?'), findsOneWidget);
    expect(find.text('For this moment'), findsNothing);

    // The history section lists the check-in just made, with a readable
    // reference — no app restart needed.
    expect(find.text('Recent check-ins'), findsOneWidget);
    expect(find.text('Genesis 1:1'), findsOneWidget);
  });
}
