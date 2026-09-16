import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/mood_controller.dart';
import 'step_scroll.dart';

class ThoughtsStep extends ConsumerStatefulWidget {
  const ThoughtsStep({super.key});

  @override
  ConsumerState<ThoughtsStep> createState() => _ThoughtsStepState();
}

class _ThoughtsStepState extends ConsumerState<ThoughtsStep> {
  /// Initialized from the controller so text survives back-navigation (the
  /// widget — and its state — is disposed whenever the wizard leaves step 2).
  late final TextEditingController _text = TextEditingController(
    text: ref.read(moodControllerProvider).userThoughts,
  );

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      final controller = ref.read(moodControllerProvider.notifier);
      controller.updateThoughts(_text.text);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moodControllerProvider);
    final controller = ref.read(moodControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // The prompt + field center when they fit and scroll when the text
          // scale or keyboard leaves too little room; the buttons stay put.
          Expanded(
            child: StepScroll(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Anything on your heart? (optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _text,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write as much or as little as you like…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(),
            )
          else if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          Row(
            children: [
              TextButton(
                onPressed: controller.back,
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: state.isLoading ? null : controller.submit,
                child: const Text('Find my verse'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
