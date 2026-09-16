import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bible/data/bible_repository.dart';
import '../../../bible/data/book_names.dart';
import '../../application/mood_controller.dart';
import '../../data/mood_history_store.dart';
import '../../domain/mood_models.dart';
import 'step_scroll.dart';

String _shortDate(DateTime d) => '${d.month}/${d.day}';

class IntensityStep extends ConsumerStatefulWidget {
  const IntensityStep({super.key});

  @override
  ConsumerState<IntensityStep> createState() => _IntensityStepState();
}

class _IntensityStepState extends ConsumerState<IntensityStep> {
  /// Restored from the already-selected level when the user navigated back
  /// to this step, so the slider doesn't snap back to the default.
  late double _score;

  @override
  void initState() {
    super.initState();
    _score = ref.read(moodControllerProvider).selectedLevel?.representativeScore ??
        5.0;
  }

  /// formatRef futures per OSIS ref — created once, so the history tiles'
  /// FutureBuilders don't re-kick a lookup on every rebuild.
  final Map<String, Future<String>> _refFutures = {};

  Future<String> _formattedRef(String osis) =>
      _refFutures[osis] ??=
          formatRef(ref.read(bibleRepositoryProvider), osis);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final level = MoodLevel.fromScore(_score);
    final history = ref.watch(moodHistoryProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // The picker centers when it fits and scrolls when the text scale
          // or keyboard leaves too little room.
          Expanded(
            child: StepScroll(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(level.emoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    level.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'How are you feeling right now?',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _score,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: dark ? AppColors.nightAccent : AppColors.accent,
                    label: _score.round().toString(),
                    onChanged: (v) => setState(() => _score = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.read(moodControllerProvider.notifier).setIntensity(_score);
                      ref.read(moodControllerProvider.notifier).nextStep();
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Recent check-ins',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: dark ? AppColors.nightMuted : AppColors.muted,
                  ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: min(history.length, 20),
                itemBuilder: (context, i) {
                  // Newest first (store keeps chronological order).
                  final record = history[history.length - 1 - i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      record.level.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: FutureBuilder<String>(
                      future: _formattedRef(record.osis),
                      builder: (context, snap) =>
                          Text(snap.data ?? record.osis),
                    ),
                    subtitle: Text(_shortDate(record.date)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
