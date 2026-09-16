import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:bible_connect/features/bible/application/reader_controller.dart';
import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/data/reading_position_store.dart';
import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_repository_test.dart' show fixtureBundle;

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(fixtureBundle())),
    ]);
    // Touch the provider so build() runs before assertions.
    container.read(readerControllerProvider);
  });

  tearDown(() => container.dispose());

  test('initIfNeeded with no saved position opens GEN 1:1', () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();

    final state = container.read(readerControllerProvider);
    expect(state.bookId, 'GEN');
    expect(state.chapter, 1);
    expect(state.selectedVerse, 1);
  });

  test('initIfNeeded with a saved position restores it', () async {
    await container
        .read(readingPositionStoreProvider)
        .save(const VerseRef(bookId: 'JHN', chapter: 1, verse: 1));

    // A fresh container over the same SharedPreferences sees the saved
    // position and restores it instead of falling back to GEN 1:1.
    final secondContainer = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bibleRepositoryProvider
          .overrideWithValue(BibleRepository(fixtureBundle())),
    ]);
    addTearDown(secondContainer.dispose);

    final controller = secondContainer.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();

    final state = secondContainer.read(readerControllerProvider);
    expect(state.bookId, 'JHN');
    expect(state.bookName, 'John');
    expect(state.chapter, 1);
    expect(state.selectedVerse, 1);
  });

  test('nextVerse within chapter moves the selection and saves position',
      () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();
    await controller.nextVerse();

    expect(container.read(readerControllerProvider).selectedVerse, 2);
    final saved = container.read(readingPositionStoreProvider).load();
    expect(saved, isNotNull);
    expect(saved!.verse, 2);
  });

  test('nextVerse across chapter boundary loads the next chapter', () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();
    await controller.openChapter('GEN', 1, focusVerse: 2);
    await controller.nextVerse();

    final state = container.read(readerControllerProvider);
    expect(state.chapter, 2);
    expect(state.selectedVerse, 1);
    expect(state.verses.length, 3);
  });

  test('previousVerse at GEN 1:1 does nothing', () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();
    await controller.previousVerse();

    final state = container.read(readerControllerProvider);
    expect(state.chapter, 1);
    expect(state.selectedVerse, 1);
  });

  test('openRef navigates to any verse', () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();
    await controller.openRef(
        const VerseRef(bookId: 'JHN', chapter: 1, verse: 1));

    final state = container.read(readerControllerProvider);
    expect(state.bookName, 'John');
    expect(state.selectedVerse, 1);
  });

  test('selectVerse updates state and persists', () async {
    final controller = container.read(readerControllerProvider.notifier);
    await controller.initIfNeeded();
    await controller.selectVerse(2);

    expect(container.read(readerControllerProvider).selectedVerse, 2);
    final saved = container.read(readingPositionStoreProvider).load();
    expect(saved, isNotNull);
    expect(saved!.verse, 2);
  });
}
