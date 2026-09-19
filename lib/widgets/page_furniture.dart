import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/typography.dart';

/// The gutter every screen is set in.
const double kGutter = 26;

/// The small-caps line that names the chapter above a screen title.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    required this.edition,
    this.centred = false,
  });

  final String text;
  final Edition edition;
  final bool centred;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: centred ? TextAlign.center : TextAlign.start,
    style: AppType.smallCaps(
      size: 13,
      trackingEm: 0.24,
      color: edition.inkAt(62),
    ),
  );
}

/// A screen's name, set large and tight.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, required this.edition});

  final String text;
  final Edition edition;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppType.serif(
      size: 46,
      weight: 500,
      trackingEm: -0.02,
      height: 1,
      color: edition.ink,
    ),
  );
}

/// A small-caps heading with an optional italic note pushed to the far side,
/// the pattern the design uses above every list.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.label, {
    super.key,
    required this.edition,
    this.note,
    this.trailing,
  });

  final String label;
  final Edition edition;

  /// Set in italic on the right, e.g. "tap a line".
  final String? note;

  /// Used instead of [note] when the right side is tappable.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: AppType.smallCaps(
          size: 13,
          trackingEm: 0.22,
          color: edition.ink,
        ),
      ),
      if (trailing != null)
        trailing!
      else if (note != null)
        Text(
          note!,
          style: AppType.serif(
            size: 13,
            italic: true,
            color: edition.inkAt(60),
          ),
        ),
    ],
  );
}

/// The "← Back" link at the top of every pushed page.
class BackLink extends StatelessWidget {
  const BackLink({super.key, required this.edition, required this.onTap});

  final Edition edition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -2),
            child: Text(
              '←',
              style: AppType.serif(size: 22, height: 1, color: edition.ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Back',
            style: AppType.smallCaps(
              size: 16,
              trackingEm: 0.14,
              height: 1,
              color: edition.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A row on a hairline-ruled list that slides right a touch as it is pressed.
class HairlineRow extends StatefulWidget {
  const HairlineRow({
    super.key,
    required this.edition,
    required this.child,
    this.onTap,
    this.verticalPadding = 15,
  });

  final Edition edition;
  final Widget child;
  final VoidCallback? onTap;
  final double verticalPadding;

  @override
  State<HairlineRow> createState() => _HairlineRowState();
}

class _HairlineRowState extends State<HairlineRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedSlide(
        // 5px of the row's own width, as the design nudges it.
        offset: _pressed ? const Offset(0.012, 0) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: widget.edition.inkAt(14))),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
