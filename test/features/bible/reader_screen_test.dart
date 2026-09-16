import 'dart:convert';

import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/core/theme/app_theme.dart';
import 'package:bible_connect/features/bible/application/reader_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/presentation/widgets/paragraph_view.dart';
import 'package:bible_connect/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_repository_test.dart' show FakeBundle, fixtureBundle;

/// One chapter with 60 verses — tall enough that verse 55 is far below the
/// fold on the test surface, so a correct auto-scroll is observable.
FakeBundle tallBundle() {
  final verses = [
    for (var i = 1; i <= 60; i++)
      {
        'v': i,
        'text':
            'Verse number $i of the long chapter, padded with enough words to '
            'give every row a comfortable height on the test surface.',
      }
  ];
  return FakeBundle({
    'assets/bible/index.json': jsonEncode({
      'books': [
        {
          'id': 'GEN', 'name': 'Genesis', 'testament': 'OT', 'chapterCount': 1
        }
      ]
    }),
    'assets/bible/books/GEN.json': jsonEncode({
      'id': 'GEN', 'name': 'Genesis', 'testament': 'OT',
      'chapters': [
        {'number': 1, 'verses': verses}
      ],
    }),
  });
}

void main() {
  testWidgets('reader renders the saved chapter and navigates verses',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(fixtureBundle())),
    ]);
    addTearDown(container.dispose);

    // BibleRepository decodes assets via `compute` (Isolate.run); its reply
    // is only delivered through the real event loop, i.e. inside
    // tester.runAsync — under the widget-test fake-async zone the future
    // would stay pending and the loading spinner would never settle.
    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    // GEN 1 opened by default, first verse text visible.
    expect(find.textContaining('In the beginning God created'), findsOneWidget);

    // Next verse arrow moves the selection indicator.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.textContaining('Genesis 1:2'), findsOneWidget);
  });

  testWidgets('selecting a far verse scrolls it accurately into view',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(tallBundle())),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    // Verse 55 is built but starts below the fold (viewport at the top).
    final viewport =
        tester.renderObject<RenderBox>(find.byType(Scrollable).first);
    final before = tester.renderObject<RenderBox>(
        find.textContaining('Verse number 55'));
    expect(
      before.localToGlobal(Offset.zero, ancestor: viewport).dy,
      greaterThan(viewport.size.height),
    );

    await container
        .read(readerControllerProvider.notifier)
        .selectVerse(55);
    await tester.pumpAndSettle();

    // ensureVisible scrolled to the verse's real, measured position: the
    // viewport moved and verse 55 is now on screen.
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));
    final after = tester.renderObject<RenderBox>(
        find.textContaining('Verse number 55'));
    final dy = after.localToGlobal(Offset.zero, ancestor: viewport).dy;
    expect(dy, inInclusiveRange(0, viewport.size.height));
  });

  testWidgets('reader auto-scrolls to the saved verse on first open',
      (tester) async {
    // Saved position on a verse below the fold: the controller applies
    // verses + selection in ONE state write, so VerseList is born with the
    // selection set — the scroll must come from the initial-mount path,
    // not from a selection change.
    SharedPreferences.setMockInitialValues({
      'reader.position':
          jsonEncode({'bookId': 'GEN', 'chapter': 1, 'verse': 55}),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(tallBundle())),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    // No selectVerse call happened: the reader opened already scrolled to
    // the saved verse.
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));
    final viewport =
        tester.renderObject<RenderBox>(find.byType(Scrollable).first);
    final box = tester.renderObject<RenderBox>(
        find.textContaining('Verse number 55'));
    final dy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    expect(dy, inInclusiveRange(0, viewport.size.height));
  });

  testWidgets('a passage that fails to load shows an error, not a spinner',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'reader.position':
          jsonEncode({'bookId': 'XXX', 'chapter': 3, 'verse': 7}),
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = BibleRepository(fixtureBundle());
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      // Cache the index so bookInfo can resolve (to null) without compute.
      await repo.loadIndex();
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('This passage could not be loaded.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(container.read(readerControllerProvider).hasError, isTrue);
    // Failed init must not count as initialized (the next build retries).
    expect(
        container.read(readerControllerProvider.notifier).initialized, isFalse);
  });

  // PRD §5.6: paragraph mode must be tested alongside verse-per-line mode.

  /// The spans of [richText] whose style carries [background], keyed by
  /// their (trimmed) text.
  Map<String, Color?> spansWithBackground(RichText richText, Color background) {
    final found = <String, Color?>{};
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        final hasBackground = span.style?.backgroundColor == background;
        if (hasBackground) found[span.text!.trim()] = span.style?.backgroundColor;
        span.children?.forEach(walk);
      }
    }

    walk(richText.text as TextSpan);
    return found;
  }

  testWidgets('paragraph mode highlights the selected verse and scrolls to it',
      (tester) async {
    // Saved position deep in a tall chapter, then toggle to paragraph mode.
    SharedPreferences.setMockInitialValues({
      'reader.position':
          jsonEncode({'bookId': 'GEN', 'chapter': 1, 'verse': 55}),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(tallBundle())),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    // Toggle to paragraph mode (icon shown while in verse-per-line mode).
    await tester.tap(find.byIcon(Icons.format_align_left));
    await tester.pumpAndSettle();
    expect(find.byType(ParagraphView), findsOneWidget);

    // The selected verse's number span AND text span carry the theme's
    // selected-verse background; unselected verses don't.
    final richText = tester.widget<RichText>(find.descendant(
      of: find.byType(ParagraphView),
      matching: find.byType(RichText),
    ));
    final highlighted = spansWithBackground(richText, AppColors.selected);
    expect(highlighted.length, 2, reason: 'number span + text span, no others');
    expect(highlighted.keys, contains('55')); // superscript number
    expect(highlighted.keys.any((k) => k.contains('Verse number 55')), isTrue);
    expect(
        highlighted.keys.any((k) => k.contains('Verse number 10')), isFalse);

    // Verse 55 starts far below the fold — the post-frame ensureVisible on
    // the WidgetSpan anchor must have scrolled the paragraph into place.
    final scrollable = tester.state<ScrollableState>(find.descendant(
      of: find.byType(ParagraphView),
      matching: find.byType(Scrollable),
    ));
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('paragraph mode auto-scrolls to the saved verse on first open',
      (tester) async {
    // Booting straight into paragraph mode with a saved position below the
    // fold: ParagraphView is BORN with the selection set, so the scroll must
    // come from the initial-mount path, not from a selection change.
    SharedPreferences.setMockInitialValues({
      'reader.position':
          jsonEncode({'bookId': 'GEN', 'chapter': 1, 'verse': 55}),
      'settings.readingMode': 'paragraph',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(tallBundle())),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await container.read(readerControllerProvider.notifier).initIfNeeded();
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const BibleConnectApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ParagraphView), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.descendant(
      of: find.byType(ParagraphView),
      matching: find.byType(Scrollable),
    ));
    expect(scrollable.position.pixels, greaterThan(0));
    final richText = tester.widget<RichText>(find.descendant(
      of: find.byType(ParagraphView),
      matching: find.byType(RichText),
    ));
    expect(
        spansWithBackground(richText, AppColors.selected).keys, contains('55'));
  });
}
