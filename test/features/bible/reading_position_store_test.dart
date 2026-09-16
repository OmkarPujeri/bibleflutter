import 'package:bible_connect/features/bible/data/reading_position_store.dart';
import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_connect/core/settings/settings_controller.dart';

void main() {
  test('save then load round-trips the ref', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final store = container.read(readingPositionStoreProvider);
    await store.save(VerseRef(bookId: 'JHN', chapter: 3, verse: 16));
    expect(store.load(), VerseRef(bookId: 'JHN', chapter: 3, verse: 16));
  });

  test('corrupt stored JSON loads as null, never throws', () async {
    SharedPreferences.setMockInitialValues({
      'reader.position': '{"bookId": "JHN", "chapter": "not-a-number"}',
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(readingPositionStoreProvider).load(), isNull);
  });

  test('no stored value loads as null', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(readingPositionStoreProvider).load(), isNull);
  });
}
