import 'dart:convert';

import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory AssetBundle so tests never touch the real 4.5MB bundle.
class FakeBundle extends AssetBundle {
  final Map<String, String> assets;
  final List<String> requested = [];
  FakeBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final value = assets[key];
    if (value == null) throw FlutterError('Missing asset: $key');
    final bytes = utf8.encode(value);
    return ByteData.view(bytes.buffer, 0, bytes.length);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requested.add(key);
    final value = assets[key];
    if (value == null) throw FlutterError('Missing asset: $key');
    return value;
  }
}

FakeBundle fixtureBundle() => FakeBundle({
      'assets/bible/index.json': jsonEncode({
        'books': [
          {
            'id': 'GEN', 'name': 'Genesis', 'testament': 'OT', 'chapterCount': 2
          },
          {
            'id': 'EXO', 'name': 'Exodus', 'testament': 'OT', 'chapterCount': 1
          },
          {
            'id': 'JHN', 'name': 'John', 'testament': 'NT', 'chapterCount': 1
          },
        ]
      }),
      'assets/bible/books/GEN.json': jsonEncode({
        'id': 'GEN', 'name': 'Genesis', 'testament': 'OT',
        'chapters': [
          {'number': 1, 'verses': [
            {'v': 1, 'text': 'In the beginning God created the heavens and the earth.'},
            {'v': 2, 'text': 'Now the earth was formless and empty.'},
          ]},
          {'number': 2, 'verses': [
            {'v': 1, 'text': 'The heavens and the earth were finished.'},
            {'v': 2, 'text': 'On the seventh day God finished his work.'},
            {'v': 3, 'text': 'And God blessed the seventh day.'},
          ]},
        ]
      }),
      'assets/bible/books/EXO.json': jsonEncode({
        'id': 'EXO', 'name': 'Exodus', 'testament': 'OT',
        'chapters': [
          {'number': 1, 'verses': [
            {'v': 1, 'text': 'Now these are the names of the sons of Israel.'},
            {'v': 2, 'text': 'Reuben, Simeon, Levi, and Judah.'},
          ]}
        ]
      }),
      'assets/bible/books/JHN.json': jsonEncode({
        'id': 'JHN', 'name': 'John', 'testament': 'NT',
        'chapters': [
          {'number': 1, 'verses': [
            {'v': 1, 'text': 'In the beginning was the Word.'},
          ]}
        ]
      }),
    });

/// Fixture with non-contiguous verse numbers, mirroring the real WEB edition
/// (LUK 17 skips v36, ACT 8 skips v37, ACT 15 skips v34, ACT 24 skips v7):
/// - ACT 1 has verses [1, 2, 4] (v3 is missing).
/// - LUK 1 has verses [1, 2, 3, 5] (v4 missing; 4 verses, last existing v=5).
FakeBundle gapFixtureBundle() => FakeBundle({
      'assets/bible/index.json': jsonEncode({
        'books': [
          {
            'id': 'LUK', 'name': 'Luke', 'testament': 'NT', 'chapterCount': 2
          },
          {
            'id': 'ACT', 'name': 'Acts', 'testament': 'NT', 'chapterCount': 1
          },
        ]
      }),
      'assets/bible/books/LUK.json': jsonEncode({
        'id': 'LUK', 'name': 'Luke', 'testament': 'NT',
        'chapters': [
          {'number': 1, 'verses': [
            {'v': 1, 'text': 'Luke chapter one, verse one.'},
            {'v': 2, 'text': 'Luke chapter one, verse two.'},
            {'v': 3, 'text': 'Luke chapter one, verse three.'},
            {'v': 5, 'text': 'Luke chapter one, verse five.'},
          ]},
          {'number': 2, 'verses': [
            {'v': 1, 'text': 'Luke chapter two, verse one.'},
          ]},
        ]
      }),
      'assets/bible/books/ACT.json': jsonEncode({
        'id': 'ACT', 'name': 'Acts', 'testament': 'NT',
        'chapters': [
          {'number': 1, 'verses': [
            {'v': 1, 'text': 'Acts chapter one, verse one.'},
            {'v': 2, 'text': 'Acts chapter one, verse two.'},
            {'v': 4, 'text': 'Acts chapter one, verse four.'},
          ]}
        ]
      }),
    });

void main() {
  late BibleRepository repo;
  late FakeBundle bundle;

  setUp(() {
    bundle = fixtureBundle();
    repo = BibleRepository(bundle);
  });

  test('loadIndex returns books in canonical order', () async {
    final books = await repo.loadIndex();
    expect(books.map((b) => b.id), ['GEN', 'EXO', 'JHN']);
  });

  test('loadChapter returns verses and caches the book file', () async {
    final ch = await repo.loadChapter('GEN', 1);
    expect(ch!.verses.length, 2);
    expect(ch.verses.first.text, contains('In the beginning'));
    await repo.loadChapter('GEN', 2);
    // GEN.json read from assets only once — second chapter hits the cache.
    expect(
      bundle.requested.where((k) => k.contains('GEN')).length,
      1,
    );
  });

  test('loadChapter returns null for unknown book or chapter', () async {
    expect(await repo.loadChapter('REV', 1), isNull);
    expect(await repo.loadChapter('GEN', 99), isNull);
  });

  test('findVerse resolves an OSIS-style ref', () async {
    final verse = await repo.findVerse(
      VerseRef(bookId: 'GEN', chapter: 2, verse: 3),
    );
    expect(verse!.text, contains('blessed the seventh day'));
  });

  group('nextVerse', () {
    test('within a chapter', () async {
      final next = await repo.nextVerse(VerseRef(bookId: 'GEN', chapter: 1, verse: 1));
      expect(next, VerseRef(bookId: 'GEN', chapter: 1, verse: 2));
    });

    test('across a chapter boundary', () async {
      final next = await repo.nextVerse(VerseRef(bookId: 'GEN', chapter: 1, verse: 2));
      expect(next, VerseRef(bookId: 'GEN', chapter: 2, verse: 1));
    });

    test('across a book boundary', () async {
      final next = await repo.nextVerse(VerseRef(bookId: 'GEN', chapter: 2, verse: 3));
      expect(next, VerseRef(bookId: 'EXO', chapter: 1, verse: 1));
    });

    test('null at the end of the Bible', () async {
      final next = await repo.nextVerse(VerseRef(bookId: 'JHN', chapter: 1, verse: 1));
      expect(next, isNull);
    });

    test('skips a missing verse number (gap)', () async {
      final gapRepo = BibleRepository(gapFixtureBundle());
      final next = await gapRepo.nextVerse(
        VerseRef(bookId: 'ACT', chapter: 1, verse: 2),
      );
      expect(next, VerseRef(bookId: 'ACT', chapter: 1, verse: 4));
    });
  });

  group('previousVerse', () {
    test('within a chapter', () async {
      final prev = await repo.previousVerse(VerseRef(bookId: 'GEN', chapter: 2, verse: 3));
      expect(prev, VerseRef(bookId: 'GEN', chapter: 2, verse: 2));
    });

    test('across a chapter boundary lands on the last verse', () async {
      final prev = await repo.previousVerse(VerseRef(bookId: 'GEN', chapter: 2, verse: 1));
      expect(prev, VerseRef(bookId: 'GEN', chapter: 1, verse: 2));
    });

    test('across a book boundary', () async {
      final prev = await repo.previousVerse(VerseRef(bookId: 'EXO', chapter: 1, verse: 1));
      expect(prev, VerseRef(bookId: 'GEN', chapter: 2, verse: 3));
    });

    test('null at the start of the Bible', () async {
      final prev = await repo.previousVerse(VerseRef(bookId: 'GEN', chapter: 1, verse: 1));
      expect(prev, isNull);
    });

    test('skips a missing verse number (gap)', () async {
      final gapRepo = BibleRepository(gapFixtureBundle());
      final prev = await gapRepo.previousVerse(
        VerseRef(bookId: 'ACT', chapter: 1, verse: 4),
      );
      expect(prev, VerseRef(bookId: 'ACT', chapter: 1, verse: 2));
    });

    test('chapter boundary lands on the last existing verse, not the count', () async {
      final gapRepo = BibleRepository(gapFixtureBundle());
      final prev = await gapRepo.previousVerse(
        VerseRef(bookId: 'LUK', chapter: 2, verse: 1),
      );
      // LUK 1 has 4 verses [1, 2, 3, 5] — the last existing verse is 5.
      expect(prev, VerseRef(bookId: 'LUK', chapter: 1, verse: 5));
    });
  });
}
