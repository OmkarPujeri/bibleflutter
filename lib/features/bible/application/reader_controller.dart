import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider lives in the legacy library as of Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/debug_report.dart';
import '../data/bible_repository.dart';
import '../data/reading_position_store.dart';
import '../domain/bible_models.dart';

class ReaderState {
  const ReaderState({
    this.bookId = 'GEN',
    this.bookName = '',
    this.chapter = 1,
    this.verses = const [],
    this.selectedVerse,
    this.isLoading = true,
    this.hasError = false,
  });

  final String bookId;
  final String bookName;
  final int chapter;
  final List<Verse> verses;
  final int? selectedVerse;
  final bool isLoading;
  final bool hasError;

  ReaderState copyWith({
    String? bookId,
    String? bookName,
    int? chapter,
    List<Verse>? verses,
    int? selectedVerse,
    bool? isLoading,
    bool? hasError,
  }) =>
      ReaderState(
        bookId: bookId ?? this.bookId,
        bookName: bookName ?? this.bookName,
        chapter: chapter ?? this.chapter,
        verses: verses ?? this.verses,
        selectedVerse: selectedVerse,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
      );
}

/// Cross-tab "open this verse in the reader" signal. Mood result sets it;
/// ReaderScreen listens and consumes it.
final readerOpenRequestProvider = StateProvider<VerseRef?>((ref) => null);

class ReaderController extends Notifier<ReaderState> {
  bool initialized = false;

  /// Monotonic token for open requests. Cold-start [initIfNeeded] and a
  /// cross-tab [openRef] can interleave; each request remembers its token,
  /// and any request whose token has been superseded aborts after its
  /// awaits — no state write, no position save. Latest request wins.
  int _requestToken = 0;

  @override
  ReaderState build() => const ReaderState();

  BibleRepository get _repo => ref.read(bibleRepositoryProvider);

  /// Opens the saved position (or Genesis 1:1 on first run). Idempotent, and
  /// never throws: a failed load leaves an error state and `initialized`
  /// false so the next build retries.
  Future<void> initIfNeeded() async {
    if (initialized) return;
    initialized = true;
    final token = ++_requestToken;
    try {
      final saved = ref.read(lastReadProvider);
      final start =
          saved ?? const VerseRef(bookId: 'GEN', chapter: 1, verse: 1);
      await _openRef(start, save: saved == null, token: token);
      if (token != _requestToken) return; // superseded by a newer open
      if (state.hasError) initialized = false;
    } catch (e, st) {
      reportCaughtError(e, st, context: 'opening the saved reading position');
      initialized = false;
      if (token != _requestToken) return; // superseded: don't clobber state
      _failLoad();
    }
  }

  Future<void> openChapter(String bookId, int chapter, {int? focusVerse}) =>
      openRef(
        VerseRef(
          bookId: bookId,
          chapter: chapter,
          verse: focusVerse ?? 1,
        ),
      );

  Future<void> openRef(VerseRef ref, {bool save = true}) =>
      _openRef(ref, save: save, token: ++_requestToken);

  Future<void> _openRef(
    VerseRef ref, {
    required bool save,
    required int token,
  }) async {
    try {
      final info = await _repo.bookInfo(ref.bookId);
      if (token != _requestToken) return;
      final chapter = await _repo.loadChapter(ref.bookId, ref.chapter);
      if (token != _requestToken) return;
      if (info == null || chapter == null) {
        _failLoad();
        return;
      }

      state = state.copyWith(
        bookId: ref.bookId,
        bookName: info.name,
        chapter: ref.chapter,
        verses: chapter.verses,
        selectedVerse: ref.verse,
        isLoading: false,
        hasError: false,
      );
      if (save && token == _requestToken) {
        // `this.ref` because the [VerseRef] parameter shadows the Notifier's Ref.
        await this.ref.read(lastReadProvider.notifier).save(
              VerseRef(
                bookId: ref.bookId,
                chapter: ref.chapter,
                verse: ref.verse,
              ),
            );
      }
    } catch (e, st) {
      reportCaughtError(e, st, context: 'loading ${ref.bookId} ${ref.chapter}');
      if (token != _requestToken) return; // superseded: don't clobber state
      _failLoad();
    }
  }

  /// Stops the spinner and shows the reader's error state. Idempotent:
  /// ReaderScreen retries [initIfNeeded] on every build after a failure, and
  /// copyWith always yields a new object — updating unconditionally would
  /// rebuild (and retry) forever.
  void _failLoad() {
    if (!state.isLoading && state.hasError) return;
    state = state.copyWith(isLoading: false, hasError: true);
  }

  /// Selects a verse (e.g. tapped in the verse list) and persists the
  /// position so the reader reopens where the user left off.
  Future<void> selectVerse(int v) async {
    state = state.copyWith(selectedVerse: v);
    await ref.read(lastReadProvider.notifier).save(
          VerseRef(
            bookId: state.bookId,
            chapter: state.chapter,
            verse: v,
          ),
        );
  }

  Future<void> nextVerse() => _move(forward: true);
  Future<void> previousVerse() => _move(forward: false);

  Future<void> _move({required bool forward}) async {
    final s = state;
    final current = VerseRef(
      bookId: s.bookId,
      chapter: s.chapter,
      verse: s.selectedVerse ?? 1,
    );
    final target = forward
        ? await _repo.nextVerse(current)
        : await _repo.previousVerse(current);
    if (target == null) return;

    if (target.bookId == s.bookId && target.chapter == s.chapter) {
      state = state.copyWith(selectedVerse: target.verse);
      await ref
          .read(lastReadProvider.notifier)
          .save(VerseRef(
            bookId: target.bookId,
            chapter: target.chapter,
            verse: target.verse,
          ));
    } else {
      await openRef(target);
    }
  }
}

final readerControllerProvider =
    NotifierProvider<ReaderController, ReaderState>(ReaderController.new);
