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

  @override
  Widget build(BuildContext context) {
    // The design's 30px of space under the tabs is an allowance for the home
    // indicator, so a device that asks for more gets it.
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: edition.paper,
        border: Border(top: BorderSide(color: edition.inkAt(16))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottom > 30 ? bottom : 30),
        child: Row(
          children: [
            _tab(NavTab.home),
            _tab(NavTab.collection),
            SizedBox(
              width: 76,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -lift),
                  child: _AddButton(edition: edition, onTap: onAdd),
                ),
              ),
            ),
            _tab(NavTab.years),
            _tab(NavTab.profile),
          ],
        ),
      ),
    );
  }

  Widget _tab(NavTab tab) {
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
                  size: 15,
                  trackingEm: 0.16,
                  color: active ? edition.ink : edition.muted,
                ),
                child: Text(tab.label),
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
