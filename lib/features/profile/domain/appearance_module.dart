import 'dart:ui';

enum AppearanceModule {
  ledger('账单', 'ledger'),
  statistics('统计', 'statistics'),
  editor('记一笔', 'editor'),
  profile('我的', 'profile'),
  navigation('底部导航', 'navigation');

  const AppearanceModule(this.label, this.storageKey);

  final String label;
  final String storageKey;
}

class ModuleAppearance {
  const ModuleAppearance({required this.color, required this.panelOpacity});

  final Color color;
  final double panelOpacity;

  ModuleAppearance copyWith({Color? color, double? panelOpacity}) =>
      ModuleAppearance(
        color: color ?? this.color,
        panelOpacity: panelOpacity ?? this.panelOpacity,
      );
}
