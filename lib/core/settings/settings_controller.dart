import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the already-loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main()'),
);

enum ReadingMode { versePerLine, paragraph }

const _kTextScaleKey = 'settings.textScale';
const _kReadingModeKey = 'settings.readingMode';
const _kFontScaleKey = 'settings.fontScale';

class SettingsState {
  const SettingsState({
    this.textScale = 1.0,
    this.readingMode = ReadingMode.versePerLine,
    this.fontScale = 1.0,
  });

  final double textScale;
  final ReadingMode readingMode;
  final double fontScale;

  SettingsState copyWith({
    double? textScale,
    ReadingMode? readingMode,
    double? fontScale,
  }) =>
      SettingsState(
        textScale: textScale ?? this.textScale,
        readingMode: readingMode ?? this.readingMode,
        fontScale: fontScale ?? this.fontScale,
      );
}

class SettingsController extends Notifier<SettingsState> {
  late final SharedPreferences _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return SettingsState(
      textScale: _prefs.getDouble(_kTextScaleKey) ?? 1.0,
      readingMode: (_prefs.getString(_kReadingModeKey) == 'paragraph')
          ? ReadingMode.paragraph
          : ReadingMode.versePerLine,
      fontScale: _prefs.getDouble(_kFontScaleKey) ?? 1.0,
    );
  }

  Future<void> setTextScale(double value) async {
    final clamped = value.clamp(0.85, 1.6);
    await _prefs.setDouble(_kTextScaleKey, clamped);
    state = state.copyWith(textScale: clamped);
  }

  Future<void> setReadingMode(ReadingMode mode) async {
    await _prefs.setString(
        _kReadingModeKey, mode == ReadingMode.paragraph ? 'paragraph' : 'verse');
    state = state.copyWith(readingMode: mode);
  }

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(0.85, 1.6);
    await _prefs.setDouble(_kFontScaleKey, clamped);
    state = state.copyWith(fontScale: clamped);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
