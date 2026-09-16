import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bible/domain/bible_models.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mood_controller.dart';
import '../data/mood_history_store.dart';
import 'widgets/intensity_step.dart';
import 'widgets/mood_result_view.dart';
import 'widgets/question_step.dart';
import 'widgets/thoughts_step.dart';

class MoodTab extends ConsumerWidget {
  const MoodTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moodControllerProvider);
    final controller = ref.read(moodControllerProvider.notifier);
    final today = ref.watch(todaysMoodProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Today's saved check-in wins at step 0 — but only if its osis parses;
    // a corrupt record must fall through to the wizard, not red-screen.
    final todayRef = (today != null && state.step == 0 && !state.overrideToday)
        ? VerseRef.parse(today.osis)
        : null;

    final Widget body;
    if (state.recommendedVerse != null) {
      body = MoodResultView(result: state.recommendedVerse!);
    } else if (todayRef != null) {
      body = MoodResultView(result: todayRef);
    } else {
      body = switch (state.step) {
        0 => const IntensityStep(),
        1 => const QuestionStep(),
        _ => const ThoughtsStep(),
      };
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Mood Check-in',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Start over',
            icon: Icon(Icons.refresh,
                color: dark ? AppColors.nightMuted : AppColors.muted),
            // startNewCheckIn (not reset): after a same-day check-in the
            // today-result branch would otherwise win at step 0 and the
            // button would appear inert.
            onPressed: controller.startNewCheckIn,
          ),
        ],
      ),
      body: body,
    );
  }
}
