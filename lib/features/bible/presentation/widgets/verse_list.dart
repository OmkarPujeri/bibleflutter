import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/bible_models.dart';

/// Verse-per-line mode. Selection taps scroll the prev/next highlight;
/// a tap sets the current verse for navigation purposes.
class VerseList extends ConsumerStatefulWidget {
  const VerseList({
    super.key,
    required this.verses,
    required this.selectedVerse,
    required this.fontScale,
    this.onSelect,
  });

  final List<Verse> verses;
  final int? selectedVerse;
  final double fontScale;
  final ValueChanged<int>? onSelect;

  @override
  ConsumerState<VerseList> createState() => _VerseListState();
}

class _VerseListState extends ConsumerState<VerseList> {
  /// One key per verse VALUE (WEB chapters skip verse numbers), reused
  /// across rebuilds so we can locate the selected verse's BuildContext and
  /// let the framework scroll to its real, measured position — no per-verse
  /// height estimates. All verses are built (a chapter holds at most ~176),
  /// so every key has a context and the target can always be found.
  final Map<int, GlobalKey> _verseKeys = {};

  GlobalKey _keyFor(int verse) => _verseKeys[verse] ??= GlobalKey();

  @override
  void initState() {
    super.initState();
    // First mount: the controller applies the saved verse in the same state
    // write that supplies the verses, so this widget can be BORN with a
    // selection already set — didUpdateWidget alone would never fire, and
    // the reader would open at the top of the chapter instead of at the
    // saved verse. The post-frame callback runs after the first build, so
    // every verse key has its context by then.
    if (widget.selectedVerse != null) {
      _scrollToSelected(widget.selectedVerse!);
    }
  }

  @override
  void didUpdateWidget(VerseList old) {
    super.didUpdateWidget(old);
    // Scroll when the selection moves, or when a new chapter replaces the
    // list (cross-chapter jumps must land on the focused verse even when
    // the verse number happens to be unchanged, e.g. GEN 1:1 -> GEN 2:1).
    if ((widget.selectedVerse != old.selectedVerse ||
            widget.verses != old.verses) &&
        widget.selectedVerse != null) {
      _scrollToSelected(widget.selectedVerse!);
    }
  }

  void _scrollToSelected(int verse) {
    // Post-frame: the list may be rebuilding with new verses this frame, so
    // the target context must be looked up after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _verseKeys[verse]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.3, // target ~30% from the top so context stays visible
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 18 * widget.fontScale,
          height: 1.5,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final verse in widget.verses)
            InkWell(
              key: _keyFor(verse.v),
              onTap: () => widget.onSelect?.call(verse.v),
              child: Container(
                color: verse.v == widget.selectedVerse
                    ? (dark ? AppColors.nightSelected : AppColors.selected)
                    : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.v} ',
                        style: TextStyle(
                          fontSize: 12 * widget.fontScale,
                          fontWeight: FontWeight.bold,
                          color: dark
                              ? AppColors.nightAccent
                              : AppColors.accent,
                        ),
                      ),
                      TextSpan(text: verse.text, style: style),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
