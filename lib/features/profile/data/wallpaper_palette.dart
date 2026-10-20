import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/appearance_module.dart';

abstract final class WallpaperPalette {
  static Future<Map<AppearanceModule, Color>> fromBytes(Uint8List bytes) async {
    final scheme = await _scheme(bytes);
    return _previousPalette(scheme);
  }

  /// Restores the previous automatic palette after the contrast experiment.
  /// User-selected colors are kept.
  static Future<Map<AppearanceModule, Color>> restorePreviousPalette(
    Uint8List bytes,
    Map<AppearanceModule, Color> current,
  ) async {
    final scheme = await _scheme(bytes);
    final previous = _previousPalette(scheme);
    final experimental = _experimentalPalette(scheme.primary);
    return {
      for (final module in AppearanceModule.values)
        if (current[module] == experimental[module]) module: previous[module]!,
    };
  }

  static Map<AppearanceModule, Color> _previousPalette(ColorScheme scheme) => {
    AppearanceModule.ledger: scheme.primary,
    AppearanceModule.statistics: scheme.secondary,
    AppearanceModule.editor: scheme.tertiary,
    AppearanceModule.profile: Color.lerp(scheme.primary, scheme.tertiary, 0.5)!,
    AppearanceModule.navigation: Color.lerp(
      scheme.primary,
      scheme.secondary,
      0.35,
    )!,
  };

  static Future<ColorScheme> _scheme(Uint8List bytes) =>
      ColorScheme.fromImageProvider(
        provider: MemoryImage(bytes),
        brightness: Brightness.light,
      );

  /// Only used to recognize and undo colors saved by the brief experiment.
  static Map<AppearanceModule, Color> _experimentalPalette(
    Color wallpaperColor,
  ) {
    final base = HSLColor.fromColor(wallpaperColor);
    final hue = base.saturation < 0.12 ? 180.0 : base.hue;
    const hueOffsets = <AppearanceModule, double>{
      AppearanceModule.ledger: 160,
      AppearanceModule.statistics: 195,
      AppearanceModule.editor: 225,
      AppearanceModule.profile: 135,
      AppearanceModule.navigation: 180,
    };
    const lightness = <AppearanceModule, double>{
      AppearanceModule.ledger: 0.31,
      AppearanceModule.statistics: 0.29,
      AppearanceModule.editor: 0.32,
      AppearanceModule.profile: 0.30,
      AppearanceModule.navigation: 0.27,
    };
    final saturation = base.saturation < 0.12
        ? 0.45
        : (base.saturation * 0.7).clamp(0.46, 0.64);
    return {
      for (final module in AppearanceModule.values)
        module: _darkAccent(
          (hue + hueOffsets[module]!) % 360,
          saturation,
          lightness[module]!,
        ),
    };
  }

  static Color _darkAccent(double hue, double saturation, double lightness) {
    var tone = lightness;
    var color = HSLColor.fromAHSL(1, hue, saturation, tone).toColor();
    while (color.computeLuminance() > 0.10 && tone > 0.12) {
      tone -= 0.01;
      color = HSLColor.fromAHSL(1, hue, saturation, tone).toColor();
    }
    return color;
  }
}
