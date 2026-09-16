import 'package:flutter/foundation.dart';

/// Fail-fast in debug, silent-safe in release (PRD §5.5).
///
/// Reports a caught-and-recovered error to Flutter's error console so it is
/// loud in debug builds and test runs, while compiling to a no-op in release
/// where the caller's fallback behavior simply proceeds.
void reportCaughtError(
  Object error,
  StackTrace stackTrace, {
  String? context,
}) {
  assert(() {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'bible_connect',
      context: ErrorDescription('recovered while ${context ?? 'handling an error'}'),
      informationCollector: () => [
        ErrorHint(
          'This error was caught and a fallback is applied; it is reported '
          'so it is not silently swallowed in debug builds.',
        ),
      ],
    ));
    return true;
  }());
}
