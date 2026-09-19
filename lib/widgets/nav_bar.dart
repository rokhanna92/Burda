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

  /// The label size that lets the longest tab sit on one line.
  ///
  /// "Collection" is half again as wide as "Index", and at phone width the
  /// design's 15px does not fit the column, so it wrapped. Rather than pick a
  /// smaller number and hope, this measures the real font and scales every
  /// label by the same amount, so the four stay the same size as each other on
  /// any screen.
  static double _labelSize(double available) {
    const wanted = 15.0;
    var widest = 0.0;

    for (final tab in NavTab.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: tab.label,
          style: AppType.smallCaps(size: wanted, trackingEm: 0.16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      widest = math.max(widest, painter.width);
    }

    if (widest <= available || widest == 0) return wanted;
    return wanted * available / widest;
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
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottom),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = _labelSize((constraints.maxWidth - 76) / 4);

            return Row(
              children: [
                _tab(NavTab.home, size),
                _tab(NavTab.collection, size),
                SizedBox(
                  width: 76,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -lift),
                      child: _AddButton(edition: edition, onTap: onAdd),
                    ),
                  ),
                ),
                _tab(NavTab.years, size),
                _tab(NavTab.profile, size),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tab(NavTab tab, double size) {
    final active = tab == current;

    return Expanded(
      child: GestureDetector(
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
                  trackingEm: 0.16,
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
