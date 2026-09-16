/// Pure data models for the bundled WEB Bible. OSIS book IDs (`JHN.3.16`)
/// are the internal reference format everywhere in the app.
library;

class BookInfo {
  const BookInfo({
    required this.id,
    required this.name,
    required this.testament,
    required this.chapterCount,
  });

  final String id;
  final String name;
  final String testament; // 'OT' | 'NT'
  final int chapterCount;

  factory BookInfo.fromJson(Map<String, dynamic> json) => BookInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        testament: json['testament'] as String,
        chapterCount: json['chapterCount'] as int,
      );
}

class BibleIndex {
  const BibleIndex(this.books);

  final List<BookInfo> books;

  factory BibleIndex.fromJson(Map<String, dynamic> json) => BibleIndex(
        [(json['books'] as List)]
            .expand((l) => l)
            .map((e) => BookInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Verse {
  const Verse({required this.v, required this.text});

  final int v;
  final String text;

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
        v: json['v'] as int,
        text: json['text'] as String,
      );
}

class Chapter {
  const Chapter({required this.number, required this.verses});

  final int number;
  final List<Verse> verses;

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        number: json['number'] as int,
        verses: [
          (json['verses'] as List)
              .map((e) => Verse.fromJson(e as Map<String, dynamic>))
        ].expand((l) => l).toList(),
      );
}

class BookContent {
  const BookContent({
    required this.id,
    required this.name,
    required this.testament,
    required this.chapters,
  });

  final String id;
  final String name;
  final String testament;
  final List<Chapter> chapters;

  factory BookContent.fromJson(Map<String, dynamic> json) => BookContent(
        id: json['id'] as String,
        name: json['name'] as String,
        testament: json['testament'] as String,
        chapters: [
          (json['chapters'] as List)
              .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        ].expand((l) => l).toList(),
      );
}

class VerseRef {
  const VerseRef({required this.bookId, required this.chapter, required this.verse});

  final String bookId;
  final int chapter;
  final int verse;

  String get osis => '$bookId.$chapter.$verse';

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.bookId == bookId &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);

  /// Parses `BOOK.chapter.verse`; returns null for anything malformed —
  /// wrong shape, non-numeric parts, empty book id, or chapter/verse < 1 —
  /// so persisted garbage can never crash the UI.
  static VerseRef? parse(String osis) {
    final parts = osis.split('.');
    if (parts.length != 3) return null;
    final chapter = int.tryParse(parts[1]);
    final verse = int.tryParse(parts[2]);
    if (chapter == null || verse == null) return null;
    if (parts[0].isEmpty || chapter < 1 || verse < 1) return null;
    return VerseRef(bookId: parts[0], chapter: chapter, verse: verse);
  }
}
