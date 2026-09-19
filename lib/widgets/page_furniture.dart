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
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: AppType.smallCaps(
            size: 13,
            trackingEm: 0.22,
            color: edition.ink,
          ),
        ),
      ),
      const SizedBox(width: 10),
      if (trailing != null)
        Flexible(child: trailing!)
      else if (note != null)
        Flexible(
          child: Text(
            note!,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppType.serif(
              size: 13,
              italic: true,
              color: edition.inkAt(60),
            ),
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

/// Shrinks its child while it is held, the design's press on every button.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOut,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final Duration duration;
  final Curve curve;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    child: AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: widget.duration,
      curve: widget.curve,
      child: widget.child,
    ),
  );
}

/// A small-caps button, either printed in ink or merely outlined in it.
class BurdaButton extends StatelessWidget {
  const BurdaButton({
    super.key,
    required this.edition,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.glyph,
    this.size = 16,
    this.trackingEm = 0.14,
    this.padding = const EdgeInsets.all(15),
    this.pressScale = 0.97,
  });

  final Edition edition;
  final String label;
  final VoidCallback? onTap;

  /// Ink block with paper lettering, rather than an outline.
  final bool filled;

  /// Set larger and to the left of the label, e.g. the heart on the own button.
  final String? glyph;

  final double size;
  final double trackingEm;
  final EdgeInsets padding;
  final double pressScale;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? edition.paper : edition.ink;

    return PressScale(
      onTap: onTap,
      scale: pressScale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: padding,
        decoration: BoxDecoration(
          color: filled ? edition.ink : Colors.transparent,
          border: Border.all(color: edition.ink),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (glyph != null) ...[
              Text(
                glyph!,
                style: AppType.serif(size: 20, height: 1, color: foreground),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppType.smallCaps(
                  size: size,
                  trackingEm: trackingEm,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
