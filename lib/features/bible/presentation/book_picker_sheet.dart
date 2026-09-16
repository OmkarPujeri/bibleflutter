import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/reader_controller.dart';
import '../data/bible_repository.dart';
import '../domain/bible_models.dart';

/// Pure filter logic — tested directly.
List<BookInfo> filterBooks(
    List<BookInfo> books, String query, String? testament) {
  return books.where((b) {
    if (testament != null && b.testament != testament) return false;
    if (query.trim().isNotEmpty &&
        !b.name.toLowerCase().contains(query.trim().toLowerCase())) {
      return false;
    }
    return true;
  }).toList();
}

Future<void> showBookPickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    // Push on the ROOT navigator: the per-tab navigator never sees the
    // route, so system back would otherwise pop the app instead of the
    // sheet. The sheet covers the tab bar (85% height) — acceptable.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor:
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.nightSurface
            : AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _BookPickerSheet(),
  );
}

class _BookPickerSheet extends ConsumerStatefulWidget {
  const _BookPickerSheet();

  @override
  ConsumerState<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends ConsumerState<_BookPickerSheet> {
  String _query = '';
  String? _testament; // null = all
  BookInfo? _selectedBook;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final index = ref.watch(bibleIndexProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? AppColors.nightRule : AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  hintText: _selectedBook == null
                      ? 'Search books…'
                      : 'Search chapters in ${_selectedBook!.name}…',
                  prefixIcon: _selectedBook != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() {
                            _selectedBook = null;
                            _query = ''; // B1: don't leak the chapter filter
                          }),
                        )
                      : const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dark ? AppColors.nightRule : AppColors.rule,
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_selectedBook == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, value) in [
                      ('All', null),
                      ('Old Testament', 'OT'),
                      ('New Testament', 'NT'),
                    ])
                      FilterChip(
                        label: Text(label),
                        selected: _testament == value,
                        onSelected: (_) =>
                            setState(() => _testament = value),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: index.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load books: $e')),
                data: (books) => _selectedBook == null
                    ? _BookGrid(
                        books: filterBooks(books, _query, _testament),
                        scrollController: scrollController,
                        onTap: (b) => setState(() {
                          _selectedBook = b;
                          _query = '';
                        }),
                      )
                    : _ChapterGrid(
                        book: _selectedBook!,
                        query: _query,
                        scrollController: scrollController,
                        onTap: (chapter) {
                          ref
                              .read(readerControllerProvider.notifier)
                              .openChapter(_selectedBook!.id, chapter);
                          Navigator.of(context).pop();
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.books,
    required this.scrollController,
    required this.onTap,
  });

  final List<BookInfo> books;
  final ScrollController scrollController;
  final ValueChanged<BookInfo> onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (books.isEmpty) {
      return Center(
        child: Text('No books match',
            style: TextStyle(
              color: dark ? AppColors.nightMuted : AppColors.muted,
            )),
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final b = books[i];
        return OutlinedButton(
          onPressed: () => onTap(b),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: dark ? AppColors.nightRule : AppColors.rule,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            b.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        );
      },
    );
  }
}

class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({
    required this.book,
    required this.query,
    required this.scrollController,
    required this.onTap,
  });

  final BookInfo book;
  final String query;
  final ScrollController scrollController;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final chapters = [
      for (var i = 1; i <= book.chapterCount; i++)
        if (query.isEmpty || '$i'.contains(query)) i,
    ];
    if (chapters.isEmpty) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Text(
          'No chapters match',
          style: TextStyle(
            color: dark ? AppColors.nightMuted : AppColors.muted,
          ),
        ),
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: chapters.length,
      itemBuilder: (context, i) => OutlinedButton(
        onPressed: () => onTap(chapters[i]),
        child: Text('${chapters[i]}'),
      ),
    );
  }
}
