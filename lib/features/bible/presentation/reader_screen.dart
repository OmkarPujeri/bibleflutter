import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../application/reader_controller.dart';
import '../domain/bible_models.dart';
import 'book_picker_sheet.dart';
import 'widgets/verse_list.dart';
import 'widgets/paragraph_view.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readerControllerProvider);
    final controller = ref.read(readerControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // initIfNeeded is idempotent and never throws; `unawaited` makes the
    // intentionally dropped future explicit.
    unawaited(controller.initIfNeeded());

    // Cross-tab navigation (mood result → this reader).
    ref.listen<VerseRef?>(readerOpenRequestProvider, (prev, next) {
      if (next != null) {
        controller.openRef(next);
        ref.read(readerOpenRequestProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Tooltip(
          message: 'Choose book and chapter',
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => showBookPickerSheet(context, ref),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.isLoading
                        ? '…'
                        : '${state.bookName} ${state.chapter}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      size: 20,
                      color: dark ? AppColors.nightMuted : AppColors.muted),
                ],
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reading mode',
            onPressed: () => ref.read(settingsControllerProvider.notifier)
                .setReadingMode(
                  settings.readingMode == ReadingMode.versePerLine
                      ? ReadingMode.paragraph
                      : ReadingMode.versePerLine,
                ),
            icon: Icon(
              settings.readingMode == ReadingMode.versePerLine
                  ? Icons.format_align_left
                  : Icons.format_list_numbered,
              color: dark ? AppColors.nightAccent : AppColors.accent,
            ),
          ),
          IconButton(
            tooltip: 'Smaller text',
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setFontScale(settings.fontScale - 0.15),
            icon: Icon(Icons.text_decrease,
                color: dark ? AppColors.nightMuted : AppColors.muted),
          ),
          IconButton(
            tooltip: 'Larger text',
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setFontScale(settings.fontScale + 0.15),
            icon: Icon(Icons.text_increase,
                color: dark ? AppColors.nightAccent : AppColors.accent),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'This passage could not be loaded.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: dark
                                ? AppColors.nightMuted
                                : AppColors.muted,
                          ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: settings.readingMode == ReadingMode.versePerLine
                      ? VerseList(
                          verses: state.verses,
                          selectedVerse: state.selectedVerse,
                          fontScale: settings.fontScale,
                          onSelect: controller.selectVerse,
                        )
                      : ParagraphView(
                          verses: state.verses,
                          selectedVerse: state.selectedVerse,
                          fontScale: settings.fontScale,
                        ),
                ),
      bottomNavigationBar: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Previous verse',
            onPressed: controller.previousVerse,
            icon: Icon(Icons.chevron_left,
                size: 32,
                color: dark ? AppColors.nightMuted : AppColors.muted),
          ),
          Text(
            state.selectedVerse != null && state.verses.isNotEmpty
                ? '${state.bookName} ${state.chapter}:${state.selectedVerse}'
                : '',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: dark ? AppColors.nightMuted : AppColors.muted,
                ),
          ),
          IconButton(
            tooltip: 'Next verse',
            onPressed: controller.nextVerse,
            icon: Icon(Icons.chevron_right,
                size: 32,
                color: dark ? AppColors.nightAccent : AppColors.accent),
          ),
        ],
      ),
    );
  }
}
