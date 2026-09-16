import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/bible_models.dart';

/// Paragraph mode — continuous text with superscript verse numbers.
///
/// The selected verse gets a background highlight on its spans, and a
/// zero-size WidgetSpan anchor before it lets [Scrollable.ensureVisible]
/// scroll it into view (same pattern as [VerseList._scrollToSelected]).
class ParagraphView extends StatefulWidget {
  const ParagraphView({
    super.key,
    required this.verses,
    required this.selectedVerse,
    required this.fontScale,
  });

  final List<Verse> verses;
  final int? selectedVerse;
  final double fontScale;

  @override
  State<ParagraphView> createState() => _ParagraphViewState();
}

class _ParagraphViewState extends State<ParagraphView> {
  /// One anchor key per verse value, reused across rebuilds (see VerseList).
  final Map<int, GlobalKey> _verseKeys = {};

  GlobalKey _keyFor(int verse) => _verseKeys[verse] ??= GlobalKey();

  @override
  void initState() {
    super.initState();
    // The reader can be BORN in paragraph mode with a selection already set
    // (saved position or "Open in reader") — the initial-mount scroll must
    // happen too, not just selection changes. Mirrors VerseList.initState.
    if (widget.selectedVerse != null) {
      _scrollToSelected(widget.selectedVerse!);
    }
  }

  @override
  void didUpdateWidget(ParagraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll when the selection moves or a new chapter replaces the text
    // (cross-chapter jumps can land on the same verse number).
    if ((widget.selectedVerse != oldWidget.selectedVerse ||
            widget.verses != oldWidget.verses) &&
        widget.selectedVerse != null) {
      _scrollToSelected(widget.selectedVerse!);
    }
  }

  void _scrollToSelected(int verse) {
    // Post-frame: the text may be rebuilding with new verses this frame, so
    // the anchor's context must be looked up after layout.
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
    final accent = dark ? AppColors.nightAccent : AppColors.accent;
    // Same selected-verse treatment VerseList uses.
    final selected = dark ? AppColors.nightSelected : AppColors.selected;

    final spans = <InlineSpan>[
      for (final v in widget.verses) ...[
        // Zero-size anchor before the selected verse, used by
        // _scrollToSelected to locate it inside the flowing text.
        if (v.v == widget.selectedVerse)
          WidgetSpan(
            child: SizedBox.shrink(key: _keyFor(v.v)),
          ),
        TextSpan(
          text: '${v.v} ',
          style: TextStyle(
            fontSize: 11 * widget.fontScale,
            fontWeight: FontWeight.bold,
            color: accent,
            backgroundColor:
                v.v == widget.selectedVerse ? selected : null,
            fontFeatures: const [FontFeature.superscripts()],
          ),
        ),
        TextSpan(
          text: '${v.text} ',
          style: v.v == widget.selectedVerse
              ? TextStyle(backgroundColor: selected)
              : null,
        ),
      ],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontSize: 18 * widget.fontScale,
                height: 1.7,
              ),
          children: spans,
        ),
      ),
    );
  }
}
