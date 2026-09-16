import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/bible/application/reader_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/presentation/book_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_repository_test.dart' show fixtureBundle;

void main() {
  testWidgets('picker filters books by search query', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = BibleRepository(fixtureBundle());

    // BibleRepository decodes assets via `compute` (Isolate.run); its reply
    // is only delivered through the real event loop, i.e. inside
    // tester.runAsync. Pre-warming the index cache lets bibleIndexProvider
    // resolve without ever scheduling a compute under fake-async.
    await tester.runAsync(() async {
      await repo.loadIndex();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bibleRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showBookPickerSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Genesis'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'john');
    await tester.pumpAndSettle();
    expect(find.text('Genesis'), findsNothing);
    expect(find.text('John'), findsOneWidget);
  });

  testWidgets('picking a chapter opens it in the reader and closes the sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = BibleRepository(fixtureBundle());
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // Pre-warm everything openChapter will touch (index + JHN chapter 1)
    // so no `compute` runs under the fake-async test zone.
    await tester.runAsync(() async {
      await repo.loadIndex();
      await repo.loadChapter('JHN', 1);
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showBookPickerSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Book grid -> chapter grid.
    await tester.tap(find.text('John'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Search chapters in John'), findsOneWidget);

    // Picking chapter 1 calls openChapter and pops the sheet.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(container.read(readerControllerProvider).bookId, 'JHN');
    expect(container.read(readerControllerProvider).chapter, 1);
    expect(find.text('John'), findsNothing); // sheet closed
  });

  testWidgets('back from chapters to books resets the search query',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = BibleRepository(fixtureBundle());

    await tester.runAsync(() async {
      await repo.loadIndex();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bibleRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showBookPickerSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Filter to John only, then open its chapter grid.
    await tester.enterText(find.byType(TextField), 'john');
    await tester.pumpAndSettle();
    expect(find.text('Genesis'), findsNothing);
    await tester.tap(find.text('John'));
    await tester.pumpAndSettle();

    // Back to books: the query must be gone (Genesis is visible again).
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Search books…'), findsOneWidget);
    expect(find.text('Genesis'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
  });

  testWidgets('chapter grid shows an empty state when nothing matches',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = BibleRepository(fixtureBundle());

    await tester.runAsync(() async {
      await repo.loadIndex();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bibleRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showBookPickerSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // John has a single chapter, so '9' matches nothing.
    await tester.tap(find.text('John'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.pumpAndSettle();

    expect(find.text('No chapters match'), findsOneWidget);
  });
}
