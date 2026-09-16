import 'dart:convert';

import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookInfo decodes from index JSON', () {
    final json = jsonDecode('''
      {"id": "JHN", "name": "John", "testament": "NT", "chapterCount": 21}
    ''') as Map<String, dynamic>;
    final book = BookInfo.fromJson(json);
    expect(book.id, 'JHN');
    expect(book.name, 'John');
    expect(book.testament, 'NT');
    expect(book.chapterCount, 21);
  });

  test('BibleIndex decodes the books list', () {
    final json = jsonDecode('''
      {"books": [
        {"id": "GEN", "name": "Genesis", "testament": "OT", "chapterCount": 50},
        {"id": "JHN", "name": "John", "testament": "NT", "chapterCount": 21}
      ]}
    ''') as Map<String, dynamic>;
    final index = BibleIndex.fromJson(json);
    expect(index.books.length, 2);
    expect(index.books.first.id, 'GEN');
  });

  test('BookContent decodes chapters and verses', () {
    final json = jsonDecode('''
      {"id": "JHN", "name": "John", "testament": "NT",
       "chapters": [
         {"number": 3, "verses": [
           {"v": 16, "text": "For God so loved the world..."}
         ]}
       ]}
    ''') as Map<String, dynamic>;
    final book = BookContent.fromJson(json);
    expect(book.chapters.single.number, 3);
    expect(book.chapters.single.verses.single.v, 16);
    expect(book.chapters.single.verses.single.text, contains('loved'));
  });

  test('VerseRef osis round-trips through parse', () {
    final ref = VerseRef.parse('JHN.3.16');
    expect(ref, isNotNull);
    expect(ref!.bookId, 'JHN');
    expect(ref.chapter, 3);
    expect(ref.verse, 16);
    expect(ref.osis, 'JHN.3.16');
  });

  test('VerseRef.parse rejects malformed input with null', () {
    expect(VerseRef.parse('JHN.3'), isNull);
    expect(VerseRef.parse('junk'), isNull);
    expect(VerseRef.parse('JHN.x.y'), isNull);
  });

  test('VerseRef.parse rejects empty book, zero and negative numbers', () {
    expect(VerseRef.parse(''), isNull);
    expect(VerseRef.parse('.1.1'), isNull); // empty book id
    expect(VerseRef.parse('..'), isNull);
    expect(VerseRef.parse('GEN.0.1'), isNull); // chapter < 1
    expect(VerseRef.parse('GEN.1.0'), isNull); // verse < 1
    expect(VerseRef.parse('GEN.-1.5'), isNull); // negative chapter
    expect(VerseRef.parse('GEN.1.-5'), isNull); // negative verse
    // Sanity: valid refs on the boundary still parse.
    expect(VerseRef.parse('GEN.1.1'), isNotNull);
  });
}
