import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';

/// The one-line note that rises over the nav bar when something is filed,
/// rated or removed.
///
/// Ink on paper, italic, never wrapping. It fades and lifts 10px into place,
/// matching the design's `toastIn`, and replays whenever [message] changes so
/// a second note does not appear to sit still.
class Toast extends StatefulWidget {
  const Toast({super.key, required this.message, required this.edition});

  final String message;
  final Edition edition;

  @override
  State<Toast> createState() => _ToastState();
}

class _ToastState extends State<Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.toastIn,
  )..forward();

  @override
  void didUpdateWidget(Toast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );

    return IgnorePointer(
      child: FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 10 * (1 - curved.value)),
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.edition.ink,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x80000000),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              child: Text(
                widget.message,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(
                  size: 16,
                  italic: true,
                  color: widget.edition.paper,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
