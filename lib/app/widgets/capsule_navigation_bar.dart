import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CapsuleNavigationBar extends StatelessWidget {
  const CapsuleNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    _Destination('账单', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Destination('统计', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _Destination('我的', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: AppColors.panel(context),
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (var index = 0; index < _destinations.length; index++)
                    Expanded(
                      child: _CapsuleDestination(
                        destination: _destinations[index],
                        selected: selectedIndex == index,
                        color: scheme.primary.withValues(
                          alpha:
                              0.12 +
                              (Theme.of(
                                        context,
                                      ).extension<PanelAppearance>()?.opacity ??
                                      1) *
                                  0.24,
                        ),
                        onColor: scheme.primary,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _CapsuleDestination extends StatelessWidget {
  const _CapsuleDestination({
    required this.destination,
    required this.selected,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: destination.label,
    child: InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: selected ? onColor : const Color(0xFF71817B),
              ),
              const SizedBox(width: 6),
              Text(
                destination.label,
                style: TextStyle(
                  color: selected ? onColor : const Color(0xFF71817B),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
