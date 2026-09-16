import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mood_models.dart';

// Top-level JSON decoders, kept outside the class so they capture no state:
// directly unit-testable and safe to hand to an isolate if decoding is ever
// moved off the UI thread (the same shape BibleRepository passes to compute).
Map<String, List<MoodQuestion>> _decodeQuestions(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return {
    for (final e in decoded.entries)
      e.key: (e.value as List)
          .map((q) => MoodQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
  };
}

Map<String, Map<String, List<String>>> _decodeMapping(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return {
    for (final level in decoded.entries)
      level.key: {
        for (final cat in (level.value as Map<String, dynamic>).entries)
          cat.key: List<String>.from(cat.value as List),
      },
  };
}

/// Loads the bundled mood questions and the curated verse mapping.
class MoodRepository {
  MoodRepository(this._bundle);

  final AssetBundle _bundle;
  Map<String, List<MoodQuestion>>? _questions;
  Map<String, Map<String, List<String>>>? _mapping;

  Future<Map<String, List<MoodQuestion>>> _loadQuestions() async =>
      _questions ??= _decodeQuestions(
          await _bundle.loadString('assets/mood/mood_questions.json'));

  Future<Map<String, Map<String, List<String>>>> _loadMapping() async =>
      _mapping ??= _decodeMapping(
          await _bundle.loadString('assets/mood/mood_verse_mapping.json'));

  /// All questions for a level (used by tests; deterministic).
  Future<List<MoodQuestion>> questionsFor(MoodLevel level) async =>
      (await _loadQuestions())[level.key] ?? const [];

  /// The level's category -> verse refs mapping (used by tests).
  Future<Map<String, List<String>>> mappingForLevel(MoodLevel level) async =>
      (await _loadMapping())[level.key] ?? const {};

  Future<MoodQuestion> randomQuestion(MoodLevel level, Random rng) async {
    final questions = (await _loadQuestions())[level.key]!;
    return questions[rng.nextInt(questions.length)];
  }

  Future<List<String>> versesForCategory(
      MoodLevel level, String category) async {
    final mapping = await _loadMapping();
    return mapping[level.key]?[category] ?? const [];
  }

  /// All categories that have verses for a level — used by the fallback path.
  Future<List<String>> allVerseRefsForLevel(MoodLevel level) async {
    final mapping = await _loadMapping();
    return [
      for (final refs in (mapping[level.key] ?? const {}).values) ...refs,
    ];
  }

  /// The raw mapping JSON (for debugging / potential future use).
  Future<String> rawMapping() =>
      _bundle.loadString('assets/mood/mood_verse_mapping.json');
}

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(rootBundle),
);
