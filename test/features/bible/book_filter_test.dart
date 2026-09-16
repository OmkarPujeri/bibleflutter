import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:bible_connect/features/bible/presentation/book_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

final books = [
  BookInfo(id: 'GEN', name: 'Genesis', testament: 'OT', chapterCount: 50),
  BookInfo(id: '1SA', name: '1 Samuel', testament: 'OT', chapterCount: 31),
  BookInfo(id: 'JHN', name: 'John', testament: 'NT', chapterCount: 21),
];

void main() {
  test('empty query returns all books', () {
    expect(filterBooks(books, '', null).length, 3);
  });

  test('query matches case-insensitively anywhere in the name', () {
    expect(filterBooks(books, 'gen', null).map((b) => b.id), ['GEN']);
    expect(filterBooks(books, 'JOHN', null).map((b) => b.id), ['JHN']);
    expect(filterBooks(books, 'samuel', null).map((b) => b.id), ['1SA']);
  });

  test('testament filter narrows results', () {
    expect(filterBooks(books, '', 'OT').map((b) => b.id), ['GEN', '1SA']);
    expect(filterBooks(books, '', 'NT').map((b) => b.id), ['JHN']);
  });

  test('query and testament filter combine', () {
    expect(filterBooks(books, 'j', 'OT').map((b) => b.id), []);
    expect(filterBooks(books, 'j', 'NT').map((b) => b.id), ['JHN']);
  });
}
