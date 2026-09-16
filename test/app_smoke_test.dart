import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/bible/application/reader_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/bible/bible_repository_test.dart' show fixtureBundle;

void main() {
  testWidgets('app boots to the Bible tab with both tabs present',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // The reader loads the Bible on boot — tests can't touch real assets.
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(fixtureBundle())),
    ]);
    addTearDown(container.dispose);

    // `compute` (Isolate.run) replies only through the real event loop,
    // so the initial load must run inside tester.runAsync.
    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bible'), findsOneWidget);
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Genesis 1'), findsOneWidget);

    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    expect(find.text('Mood Check-in'), findsOneWidget);
    expect(find.text('How are you feeling right now?'), findsOneWidget);
  });
}
