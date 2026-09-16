import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/bible/presentation/bible_tab.dart';
import '../../features/mood/presentation/mood_tab.dart';
import '../theme/app_theme.dart';

/// Which bottom-nav tab is showing. Mood switches the reader tab via this.
final currentTabProvider = NotifierProvider<_CurrentTabNotifier, int>(
  _CurrentTabNotifier.new,
);

class _CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentTabProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: index,
        // Each tab keeps its own Navigator so pushed screens don't cover the
        // tab bar and tab state survives switching (GitaConnect AppShell).
        children: [
          Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const BibleTab()),
          ),
          Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const MoodTab()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(currentTabProvider.notifier).set(i),
        backgroundColor: dark ? AppColors.nightSurface : AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined,
                color: dark ? AppColors.nightMuted : AppColors.muted),
            selectedIcon: Icon(Icons.menu_book,
                color: dark ? AppColors.nightAccent : AppColors.accent),
            label: 'Bible',
          ),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined,
                color: dark ? AppColors.nightMuted : AppColors.muted),
            selectedIcon: Icon(Icons.self_improvement,
                color: dark ? AppColors.nightAccent : AppColors.accent),
            label: 'Mood',
          ),
        ],
      ),
    );
  }
}
