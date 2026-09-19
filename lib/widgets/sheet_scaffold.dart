import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';

/// The one sheet the whole app uses, whatever it happens to be holding.
///
/// Rises from the bottom over a dimmed page, stops at 82% of the height and
/// scrolls inside if its contents are taller. Tapping the dimmed area closes
/// it; tapping the sheet does not.
class SheetScaffold extends StatefulWidget {
  const SheetScaffold({
    super.key,
    required this.edition,
    required this.onClose,
    required this.child,
  });

  final Edition edition;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<SheetScaffold> createState() => _SheetScaffoldState();
}

class _SheetScaffoldState extends State<SheetScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.sheetUp,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _controller, curve: AppMotion.sheet);
    // The scrim comes up faster than the sheet, as the design's .25s fadeIn.
    final dim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.ease),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: FadeTransition(
              opacity: dim,
              // The design's scrim: a warm near-black rather than pure grey.
              child: const ColoredBox(color: Color(0x6B180C0E)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(rise),
            child: GestureDetector(
              // Swallows taps so they do not reach the scrim behind.
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.edition.paper,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 50,
                        spreadRadius: -20,
                        offset: Offset(0, -20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        26,
                        14,
                        26,
                        // Clears the keyboard when the sheet holds a field.
                        46 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 18),
                              color: widget.edition.inkAt(30),
                            ),
                          ),
                          widget.child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The accent small-caps line and big name every sheet opens with.
class SheetHeading extends StatelessWidget {
  const SheetHeading({
    super.key,
    required this.edition,
    required this.eyebrow,
    required this.title,
  });

  final Edition edition;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: AppType.smallCaps(
          size: 13,
          trackingEm: 0.22,
          color: edition.accent,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: AppType.serif(
          size: 38,
          weight: 500,
          height: 1,
          color: edition.ink,
        ),
      ),
    ],
  );
}
