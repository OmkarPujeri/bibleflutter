import '../../../core/debug_report.dart';
import '../domain/bible_models.dart';
import 'bible_repository.dart';

/// 'JHN.3.16' -> 'John 3:16'. Unparsable refs come back unchanged; unknown
/// books fall back to their OSIS id. Never throws.
Future<String> formatRef(BibleRepository repo, String osis) async {
  final ref = VerseRef.parse(osis);
  if (ref == null) return osis;
  try {
    final info = await repo.bookInfo(ref.bookId);
    final name = info?.name ?? ref.bookId;
    return '$name ${ref.chapter}:${ref.verse}';
  } catch (e, st) {
    reportCaughtError(e, st, context: 'formatting $osis');
    return osis;
  }
}
