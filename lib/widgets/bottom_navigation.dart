import 'package:flutter/material.dart';

/// The five destinations, in bar order. The dress in the middle is the raised
/// add-an-issue button.
enum NavDestination {
  home('assets/icon/home.png'),
  missingByYear('assets/icon/arrow.png'),
  addIssue('assets/icon/dress.png'),
  years('assets/icon/calendar.png'),
  settings('assets/icon/settings.png');

  const NavDestination(this.asset);

  final String asset;
}

/// Pill shaped bottom bar with the raised dress in the centre.
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final NavDestination current;
  final ValueChanged<NavDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: SizedBox(
          height: 66,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    for (final destination in NavDestination.values)
                      Expanded(
                        child: destination == NavDestination.addIssue
                            ? const SizedBox.shrink()
                            : _NavIcon(
                                destination: destination,
                                selected: destination == current,
                                onTap: () => onSelected(destination),
                              ),
                      ),
                  ],
                ),
              ),
              _AddIssueButton(onTap: () => onSelected(NavDestination.addIssue)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Image.asset(
          destination.asset,
          width: 26,
          height: 26,
          color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _AddIssueButton extends StatelessWidget {
  const _AddIssueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: scheme.secondary,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/icon/dress.png',
          color: scheme.primary,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}
