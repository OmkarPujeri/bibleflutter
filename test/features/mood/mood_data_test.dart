import 'dart:math';

import 'package:bible_connect/features/bible/data/bible_repository.dart';
import 'package:bible_connect/features/bible/domain/bible_models.dart';
import 'package:bible_connect/features/mood/data/mood_repository.dart';
import 'package:bible_connect/features/mood/domain/mood_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every mood level has 3 questions with 3 categorized options each',
      () async {
    final repo = MoodRepository(rootBundle);
    for (final level in MoodLevel.values) {
      final questions = await repo.questionsFor(level);
      final mapping = await repo.mappingForLevel(level);
      expect(questions.length, 3,
          reason: '${level.key} has ${questions.length} questions');
      expect(mapping.keys, isNotEmpty,
          reason: '${level.key} has no verse categories');

      // randomQuestion must return one of this level's questions.
      final random = await repo.randomQuestion(level, Random(0));
      expect(questions.map((q) => q.id), contains(random.id));

      for (final q in questions) {
        expect(q.id, isNotEmpty);
        expect(q.question, isNotEmpty);
        expect(q.options.length, 3,
            reason: '${q.id} has ${q.options.length} options');
        for (final o in q.options) {
          expect(o.text, isNotEmpty, reason: '${q.id} has an empty option');
          expect(o.category, isNotEmpty,
              reason: '${q.id} has an option without a category');
          expect(
            mapping.keys,
            contains(o.category),
            reason:
                '${q.id}: category "${o.category}" is not a ${level.key} mapping key',
          );
        }
      }
    }
  });

  test('every level x category has verses and every OSIS ref is valid',
      () async {
    final moodRepo = MoodRepository(rootBundle);
    final bible = BibleRepository(rootBundle);
    final books = await bible.loadIndex();

    var totalRefs = 0;
    for (final level in MoodLevel.values) {
      final mapping = await moodRepo.mappingForLevel(level);
      expect(mapping.entries, isNotEmpty,
          reason: '${level.key} has no categories');
      for (final entry in mapping.entries) {
        final refs = entry.value;
        expect(refs.length, greaterThanOrEqualTo(8),
            reason: '$level/${entry.key} has ${refs.length} verses');
        for (final osis in refs) {
          totalRefs++;
          final parsed = VerseRef.parse(osis);
          expect(parsed, isNotNull, reason: 'bad OSIS ref: $osis');
          final ref = parsed!; // Nullable promotion (pre-approved fix).
          final info = books.where((b) => b.id == ref.bookId).singleOrNull;
          expect(info, isNotNull, reason: 'unknown book in $osis');
          final bookInfo = info!;
          expect(ref.chapter, lessThanOrEqualTo(bookInfo.chapterCount),
              reason: '$osis: chapter out of range');
          final chapter = await bible.loadChapter(ref.bookId, ref.chapter);
          expect(chapter, isNotNull, reason: '$osis: chapter missing');
          final ch = chapter!;
          expect(ref.verse, lessThanOrEqualTo(ch.verses.length),
              reason: '$osis: verse out of range');
          // The WEB edition skips some verse numbers, so also verify the
          // verse value actually exists in the chapter (not just the count).
          expect(
            ch.verses.any((v) => v.v == ref.verse),
            isTrue,
            reason: '$osis: verse missing from chapter',
          );
        }
      }
    }
    expect(totalRefs, greaterThanOrEqualTo(120));
    // ignore: avoid_print
    print('mood mapping: validated $totalRefs OSIS refs against WEB assets');
  });

  test('MoodLevel.fromScore maps scores to levels', () {
    expect(MoodLevel.fromScore(1.0), MoodLevel.veryUnpleasant);
    expect(MoodLevel.fromScore(4.9), MoodLevel.unpleasant);
    expect(MoodLevel.fromScore(5.5), MoodLevel.neutral);
    expect(MoodLevel.fromScore(8.0), MoodLevel.pleasant);
    expect(MoodLevel.fromScore(9.5), MoodLevel.veryPleasant);
  });

  test('fromScore band boundaries (3.0, 5.0, 7.0, 9.0) map up', () {
    expect(MoodLevel.fromScore(3.0), MoodLevel.unpleasant);
    expect(MoodLevel.fromScore(5.0), MoodLevel.neutral);
    expect(MoodLevel.fromScore(7.0), MoodLevel.pleasant);
    expect(MoodLevel.fromScore(9.0), MoodLevel.veryPleasant);
  });

  test('representativeScore maps back to the same level', () {
    expect(MoodLevel.veryUnpleasant.representativeScore, 2.0);
    expect(MoodLevel.unpleasant.representativeScore, 4.0);
    expect(MoodLevel.neutral.representativeScore, 6.0);
    expect(MoodLevel.pleasant.representativeScore, 8.0);
    expect(MoodLevel.veryPleasant.representativeScore, 10.0);
    for (final level in MoodLevel.values) {
      expect(MoodLevel.fromScore(level.representativeScore), level,
          reason: '${level.key} round-trips through fromScore');
    }
  });
}
