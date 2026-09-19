import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import 'season_window.dart';

/// The four places the nav bar can take you.
enum NavTab {
  /// Called "Index" on the bar, `home` everywhere else, as in the design.
  home('Index'),
  collection('Collection'),
  years('Years'),
  profile('Profile');

  const NavTab(this.label);

  /// As the design prints it, in small caps.
  final String label;
}

/// The bar across the bottom: four tabs around a raised seasonal window that
/// opens the add sheet.
///
/// [current] is null while a pushed page is on top, which is how the design
/// leaves every tab unlit until you are back on one.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.edition,
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  final Edition edition;
  final NavTab? current;
  final ValueChanged<NavTab> onSelect;
  final VoidCallback onAdd;

  /// How far the button rides above the bar.
  static const double lift = 30;

  /// The gutter either side of the bar.
  ///
  /// Narrower than the 18px the design gives it: that space was doing nothing
  /// but squeezing the labels, and the room is better spent on the lettering.
  static const double gutter = 6;

  /// The column the raised window sits in.
  static const double windowColumn = 76;

  /// Breathing room between one tab and the next.
  static const double gap = 6;

  /// The largest the labels can be set and still all four fit on one line.
  ///
  /// Sized against the sum of the four, not against the longest one four
  /// times over: "Index" and "Years" are short and "Collection" is not, so
  /// letting each take only the room it needs buys the lettering several
  /// points. Measured with the real font, so it holds at any width and any
  /// system text size.
  static const double _ceiling = 19;
  static const double _tracking = 0.14;

  static double _widthOf(String label, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppType.smallCaps(size: size, trackingEm: _tracking),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    // Sits on the system's own bottom inset, with nothing added: the design's
    // extra 30px was an iOS home-indicator allowance the platform already
    // gives us, and doubling it left the bar floating.
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: edition.paper,
        border: Border(top: BorderSide(color: edition.inkAt(16))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 8, gutter, bottom),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = {
              for (final tab in NavTab.values)
                tab: _widthOf(tab.label, _ceiling),
            };
            final natural = widths.values.reduce((a, b) => a + b);
            final room =
                constraints.maxWidth -
                windowColumn -
                gap * NavTab.values.length;
            final size = natural == 0
                ? _ceiling
                : math.min(_ceiling, _ceiling * room / natural);

            // Each tab takes a share of the row in proportion to its own word,
            // so the dots stay centred under the lettering rather than under
            // four identical boxes.
            Widget tab(NavTab which) => Expanded(
              flex: (widths[which]! * 100).round(),
              child: _tab(which, size),
            );

            return Row(
              children: [
                tab(NavTab.home),
                tab(NavTab.collection),
                SizedBox(
                  width: windowColumn,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -lift),
                      child: _AddButton(edition: edition, onTap: onAdd),
                    ),
                  ),
                ),
                tab(NavTab.years),
                tab(NavTab.profile),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The label and its dot. The caller decides how wide it is.
  Widget _tab(NavTab tab, double size) {
    final active = tab == current;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: AppType.smallCaps(
                size: size,
                trackingEm: _tracking,
                color: active ? edition.ink : edition.muted,
              ),
              child: Text(tab.label, maxLines: 1, softWrap: false),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? edition.accent : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised paper disc holding the seasonal window.
///
/// The paper ring is what makes it read as cut into the bar rather than sat
/// on top of it, so the ring colour follows the bar.
class _AddButton extends StatefulWidget {
  const _AddButton({required this.edition, required this.onTap});

  final Edition edition;
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppMotion.pageIn,
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.edition.paper,
            boxShadow: [
              BoxShadow(
                color: widget.edition.inkAt(22),
                blurRadius: 0,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 26,
                spreadRadius: -14,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: SeasonWindow(edition: widget.edition),
        ),
      ),
    );
  }
}
