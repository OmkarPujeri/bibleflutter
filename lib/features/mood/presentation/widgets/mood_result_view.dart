import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug_report.dart';
import '../../../../core/router/app_shell.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../bible/application/reader_controller.dart';
import '../../../bible/data/bible_repository.dart';
import '../../../bible/data/book_names.dart';
import '../../../bible/domain/bible_models.dart';

import 'step_scroll.dart';

class MoodResultView extends ConsumerStatefulWidget {
  const MoodResultView({super.key, required this.result});

  final VerseRef result;

  @override
  ConsumerState<MoodResultView> createState() => _MoodResultViewState();
}

class _MoodResultViewState extends ConsumerState<MoodResultView> {
  // Not `late final`: the same element can be asked to show a different verse
  // (today's saved mood vs. a fresh recommendation), so the future is
  // re-created when the result changes.
  late Future<({String ref, String? text})> _data;

  @override
  void initState() {
    super.initState();
    _data = _fetch();
  }

  @override
  void didUpdateWidget(MoodResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _data = _fetch();
    }
  }

  /// Human-readable reference + verse text in one pass. On failure the OSIS
  /// string is the fallback reference and the text stays '…'.
  Future<({String ref, String? text})> _fetch() async {
    try {
      final repo = ref.read(bibleRepositoryProvider);
      final formatted = await formatRef(repo, widget.result.osis);
      final verse = await repo.findVerse(widget.result);
      return (ref: formatted, text: verse?.text);
    } catch (e, st) {
      reportCaughtError(e, st,
          context: 'looking up the recommended verse');
      return (ref: widget.result.osis, text: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<({String ref, String? text})>(
      future: _data,
      builder: (context, snap) {
        final reference = snap.connectionState != ConnectionState.done
            ? '…'
            : (snap.data?.ref ?? widget.result.osis);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // The card centers when it fits and scrolls when the text
              // scale or keyboard leaves too little room.
              Expanded(
                child: StepScroll(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'For this moment',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.nightSurface
                              : AppColors.parchment,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: dark ? AppColors.nightRule : AppColors.rule,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              reference,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: dark
                                        ? AppColors.nightAccent
                                        : AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              snap.data?.text ?? '…',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontSize: 20, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('Open in reader'),
                onPressed: () {
                  ref.read(readerOpenRequestProvider.notifier).state =
                      widget.result;
                  ref.read(currentTabProvider.notifier).set(0);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
