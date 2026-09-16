import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/mood_controller.dart';

class QuestionStep extends ConsumerWidget {
  const QuestionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moodControllerProvider);
    final controller = ref.read(moodControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final question = state.followUpQuestion;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (question == null) {
      return Center(child: Text(state.error ?? 'Something went wrong.'));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${state.selectedLevel!.emoji}  One honest question:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          for (final (i, option) in question.options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => controller.selectOption(i),
                style: OutlinedButton.styleFrom(
                  backgroundColor: state.selectedOption == option.text
                      ? (dark
                          ? AppColors.nightSelected
                          : AppColors.selected)
                      : Colors.transparent,
                  side: BorderSide(
                    color: dark ? AppColors.nightRule : AppColors.rule,
                  ),
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  option.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: controller.back,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: state.selectedOption == null
                    ? null
                    : controller.nextStep,
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
