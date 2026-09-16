import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bible_models.dart';

// Top-level so `compute` can call them (no closures capturing `this`).
List<BookInfo> _decodeIndex(String raw) =>
    BibleIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>).books;

BookContent _decodeBook(String raw) =>
    BookContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// Loads the bundled WEB Bible from assets.
///
/// Book files are decoded once off the UI isolate (via `compute`) and cached
/// in memory; the index is cached the same way.
///
/// Navigation is verse-VALUE based, not index based: the WEB edition has
/// chapters with non-contiguous verse numbers (e.g. LUK 17 skips v36), so
/// `verses.length` must never be used as a verse number.
class BibleRepository {
  BibleRepository(this._bundle);

  final AssetBundle _bundle;
  final Map<String, BookContent> _cache = {};
  List<BookInfo>? _index;

  Future<List<BookInfo>> loadIndex() async {
    if (_index != null) return _index!;
    final raw = await _bundle.loadString('assets/bible/index.json');
    _index = await compute(_decodeIndex, raw);
    return _index!;
  }

  Future<BookContent> _loadBook(String bookId) async {
    return _cache[bookId] ??= await compute(
      _decodeBook,
      await _bundle.loadString('assets/bible/books/$bookId.json'),
    );
  }

  Future<Chapter?> loadChapter(String bookId, int chapter) async {
    if (!(await bookExists(bookId))) return null;
    final book = await _loadBook(bookId);
    for (final ch in book.chapters) {
      if (ch.number == chapter) return ch;
    }
    return null;
  }

  Future<Verse?> findVerse(VerseRef ref) async {
    final ch = await loadChapter(ref.bookId, ref.chapter);
    if (ch == null) return null;
    for (final v in ch.verses) {
      if (v.v == ref.verse) return v;
    }
    return null;
  }

  Future<bool> bookExists(String bookId) async =>
      (await loadIndex()).any((b) => b.id == bookId);

  Future<BookInfo?> bookInfo(String bookId) async {
    for (final b in await loadIndex()) {
      if (b.id == bookId) return b;
    }
    return null;
  }

  Future<VerseRef?> nextVerse(VerseRef ref) async {
    final info = await bookInfo(ref.bookId);
    final ch = await loadChapter(ref.bookId, ref.chapter);
    if (info == null || ch == null) return null;

    // Next verse by value: the first verse in this chapter with v > ref.verse.
    // Skips missing verse numbers (WEB: LUK 17.36, ACT 8.37, ...).
    for (final v in ch.verses) {
      if (v.v > ref.verse) {
        return VerseRef(bookId: ref.bookId, chapter: ref.chapter, verse: v.v);
      }
    }
    if (ref.chapter < info.chapterCount) {
      return VerseRef(bookId: ref.bookId, chapter: ref.chapter + 1, verse: 1);
    }
    final nextBook = await _neighborBook(ref.bookId, forward: true);
    if (nextBook == null) return null;
    return VerseRef(bookId: nextBook.id, chapter: 1, verse: 1);
  }

  Future<VerseRef?> previousVerse(VerseRef ref) async {
    final ch = await loadChapter(ref.bookId, ref.chapter);
    if (ch == null) return null;

    // Previous verse by value: the last verse in this chapter with
    // v < ref.verse. Skips missing verse numbers.
    Verse? lower;
    for (final v in ch.verses) {
      if (v.v < ref.verse) lower = v;
    }
    if (lower != null) {
      return VerseRef(bookId: ref.bookId, chapter: ref.chapter, verse: lower.v);
    }
    if (ref.chapter > 1) {
      final prev = await loadChapter(ref.bookId, ref.chapter - 1);
      if (prev == null || prev.verses.isEmpty) return null;
      return VerseRef(
        bookId: ref.bookId,
        chapter: ref.chapter - 1,
        verse: prev.verses.last.v,
      );
    }
    final prevBook = await _neighborBook(ref.bookId, forward: false);
    if (prevBook == null) return null;
    final prev = await loadChapter(prevBook.id, prevBook.chapterCount);
    if (prev == null || prev.verses.isEmpty) return null;
    return VerseRef(
      bookId: prevBook.id,
      chapter: prevBook.chapterCount,
      verse: prev.verses.last.v,
    );
  }

  Future<BookInfo?> _neighborBook(String bookId, {required bool forward}) async {
    final books = await loadIndex();
    final i = books.indexWhere((b) => b.id == bookId);
    if (i < 0) return null;
    final j = forward ? i + 1 : i - 1;
    return (j >= 0 && j < books.length) ? books[j] : null;
  }
}

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(rootBundle),
);

final bibleIndexProvider = FutureProvider<List<BookInfo>>(
  (ref) => ref.watch(bibleRepositoryProvider).loadIndex(),
);
