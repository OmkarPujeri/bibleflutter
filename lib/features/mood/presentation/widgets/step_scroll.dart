import 'package:flutter/material.dart';

/// Wraps a mood-wizard step body so it is keyboard-inset aware and never
/// overflows: the content is centered vertically when it fits the viewport
/// and scrolls when it doesn't (large text scales, soft keyboard).
///
/// The child must size itself to its content on the main axis (e.g. a
/// [Column] with `mainAxisSize: MainAxisSize.min`) — flex children (Spacer,
/// Expanded) have unbounded constraints inside a scroll view.
class StepScroll extends StatelessWidget {
  const StepScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = child;
        if (constraints.maxHeight.isFinite) {
          // Fill the viewport when the content is shorter so the child's
          // mainAxisAlignment can center it.
          content = ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          );
        }
        return SingleChildScrollView(
          // Keep the content clear of the soft keyboard.
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: content,
        );
      },
    );
  }
}
