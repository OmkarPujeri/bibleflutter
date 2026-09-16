import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/data/book_names.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Real bundled assets (index + books), the same pattern as mood_data_test.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatRef formats OSIS refs into Book C:V', () async {
    final repo = BibleRepository(rootBundle);
    expect(await formatRef(repo, 'JHN.3.16'), 'John 3:16');
    expect(await formatRef(repo, 'GEN.1.1'), 'Genesis 1:1');
  });

  test('formatRef falls back to the OSIS string for unparsable refs',
      () async {
    final repo = BibleRepository(rootBundle);
    expect(await formatRef(repo, 'not-a-ref'), 'not-a-ref');
  });

  test('formatRef falls back to the book id for unknown books', () async {
    final repo = BibleRepository(rootBundle);
    expect(await formatRef(repo, 'XXX.1.1'), 'XXX 1:1');
  });
}
