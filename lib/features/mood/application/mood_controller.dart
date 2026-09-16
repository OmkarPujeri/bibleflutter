import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bible/domain/bible_models.dart';
import '../data/mood_history_store.dart';
import '../data/mood_repository.dart';
import '../domain/mood_models.dart';

/// Injected so tests get deterministic picks.
final moodRngProvider = Provider<Random>((ref) => Random());

class MoodState {
  const MoodState({
    this.step = 0,
    this.selectedLevel,
    this.followUpQuestion,
    this.selectedOption,
    this.selectedCategory,
    this.userThoughts = '',
    this.isLoading = false,
    this.recommendedVerse,
    this.error,
    this.overrideToday = false,
  });

  final int step; // 0 intensity, 1 question, 2 thoughts/result
  final MoodLevel? selectedLevel;
  final MoodQuestion? followUpQuestion;
  final String? selectedOption;
  final String? selectedCategory;
  final String userThoughts;
  final bool isLoading;
  final VerseRef? recommendedVerse;
  final String? error;

  /// Set by [MoodController.startNewCheckIn]: show the wizard even though
  /// today's check-in already exists. In-memory only (never persisted);
  /// cleared on submit success.
  final bool overrideToday;

  MoodState copyWith({
    int? step,
    MoodLevel? selectedLevel,
    MoodQuestion? followUpQuestion,
    String? selectedOption,
    String? selectedCategory,
    String? userThoughts,
    bool? isLoading,
    VerseRef? recommendedVerse,
    String? error,
    bool? overrideToday,
    bool clearError = false,
    bool clearAnswer = false,
    bool clearResult = false,
  }) =>
      MoodState(
        step: step ?? this.step,
        selectedLevel: selectedLevel ?? this.selectedLevel,
        followUpQuestion:
            clearAnswer ? null : (followUpQuestion ?? this.followUpQuestion),
        selectedOption:
            clearAnswer ? null : (selectedOption ?? this.selectedOption),
        selectedCategory:
            clearAnswer ? null : (selectedCategory ?? this.selectedCategory),
        userThoughts: userThoughts ?? this.userThoughts,
        isLoading: isLoading ?? this.isLoading,
        recommendedVerse:
            clearResult ? null : (recommendedVerse ?? this.recommendedVerse),
        error: clearError ? null : (error ?? this.error),
        overrideToday: overrideToday ?? this.overrideToday,
      );
}

class MoodController extends Notifier<MoodState> {
  @override
  MoodState build() => const MoodState();

  MoodRepository get _repo => ref.read(moodRepositoryProvider);
  Random get _rng => ref.read(moodRngProvider);

  void setIntensity(double score) {
    state = state.copyWith(selectedLevel: MoodLevel.fromScore(score));
  }

  Future<void> nextStep() async {
    if (state.step == 0) {
      if (state.selectedLevel == null) return;
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final question = await _repo.randomQuestion(state.selectedLevel!, _rng);
        state = state.copyWith(
          step: 1,
          followUpQuestion: question,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    } else if (state.step == 1) {
      if (state.selectedOption != null) {
        state = state.copyWith(step: 2);
      }
    }
  }

  void selectOption(int index) {
    final question = state.followUpQuestion;
    if (question == null || index < 0 || index >= question.options.length) {
      return;
    }
    final option = question.options[index];
    state = state.copyWith(
      selectedOption: option.text,
      selectedCategory: option.category,
    );
  }

  void updateThoughts(String thoughts) =>
      state = state.copyWith(userThoughts: thoughts);

  void back() {
    if (state.step > 0) {
      // Stepping back invalidates the follow-up answer (GitaConnect rule):
      // a surviving selection would pair the old answer with a new question.
      state = state.copyWith(
        step: state.step - 1,
        clearAnswer: state.step == 1,
        clearError: true,
      );
    }
  }

  void reset() => state = const MoodState();

  /// Starts a fresh wizard even though today's check-in already exists (the
  /// "Start over" button). The override is in-memory only — a restart shows
  /// today's result again — and clears on submit success.
  void startNewCheckIn() => state = const MoodState(overrideToday: true);

  /// The provider is not autoDispose; without this the wizard would reopen
  /// mid-session with the previous answers.
  Future<void> submit() async {
    // Double-tap guard: while a submit is in flight, ignore further taps.
    if (state.isLoading) return;
    final level = state.selectedLevel;
    final category = state.selectedCategory;
    if (level == null || category == null) return;

    state = state.copyWith(isLoading: true, clearError: true, clearResult: true);
    try {
      final ref = await _pickVerse(level, category);
      if (ref == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not find a verse. Please try again.',
        );
        return;
      }
      await this.ref.read(moodHistoryStoreProvider).add(MoodRecord(
            date: DateTime.now(),
            osis: ref.osis,
            level: level,
          ));
      // todaysMoodProvider is effectively static (its dependency never
      // changes), so a fresh check-in must force it to recompute — otherwise
      // MoodTab would not know today's mood exists after a reset.
      this.ref.invalidate(todaysMoodProvider);
      // Refresh the reactive history so the list on the wizard start screen
      // shows the new check-in without an app restart.
      this.ref.read(moodHistoryProvider.notifier).state =
          this.ref.read(moodHistoryStoreProvider).all();
      state = state.copyWith(
        isLoading: false,
        recommendedVerse: ref,
        overrideToday: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Level ∩ category, random pick; fallback = random from the whole level.
  /// Never throws — a mapping miss degrades, it doesn't error.
  Future<VerseRef?> _pickVerse(MoodLevel level, String category) async {
    final matching = await _repo.versesForCategory(level, category);
    if (matching.isNotEmpty) {
      return VerseRef.parse(matching[_rng.nextInt(matching.length)]);
    }
    final levelWide = await _repo.allVerseRefsForLevel(level);
    if (levelWide.isEmpty) return null;
    return VerseRef.parse(levelWide[_rng.nextInt(levelWide.length)]);
  }

  /// Test seam for the fallback path.
  Future<VerseRef?> pickVerseForTest(String category) =>
      _pickVerse(state.selectedLevel ?? MoodLevel.veryUnpleasant, category);
}

final moodControllerProvider =
    NotifierProvider<MoodController, MoodState>(MoodController.new);
