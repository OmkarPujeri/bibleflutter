import 'package:bible_connect/core/settings/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('defaults: verse-per-line mode, font scale 1.0', () {
    final s = container.read(settingsControllerProvider);
    expect(s.readingMode, ReadingMode.versePerLine);
    expect(s.fontScale, 1.0);
  });

  test('font scale clamps to 0.85–1.6', () async {
    final controller = container.read(settingsControllerProvider.notifier);
    await controller.setFontScale(9.0);
    expect(container.read(settingsControllerProvider).fontScale, 1.6);
    await controller.setFontScale(0.1);
    expect(container.read(settingsControllerProvider).fontScale, 0.85);
  });

  test('reading mode persists', () async {
    await container
        .read(settingsControllerProvider.notifier)
        .setReadingMode(ReadingMode.paragraph);
    // Fresh container over the same prefs sees the persisted value.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.readingMode'), 'paragraph');
  });
}
