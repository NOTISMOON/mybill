import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF123F3A);
  static const coral = Color(0xFFE87D62);
  static const muted = Color(0xFF71817B);
  static const canvas = Color(0xFFF6F7F2);
  static const line = Color(0xFFE8ECE6);

  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color panel(BuildContext context) {
    final config = Theme.of(context).extension<PanelAppearance>();
    return Colors.white.withValues(alpha: config?.opacity ?? 1);
  }

  static Color accentPanel(BuildContext context) {
    final config = Theme.of(context).extension<PanelAppearance>();
    return primary(context).withValues(alpha: config?.opacity ?? 1);
  }
}

class PanelAppearance extends ThemeExtension<PanelAppearance> {
  const PanelAppearance({required this.opacity, required this.hasBackground});

  final double opacity;
  final bool hasBackground;

  @override
  PanelAppearance copyWith({double? opacity, bool? hasBackground}) =>
      PanelAppearance(
        opacity: opacity ?? this.opacity,
        hasBackground: hasBackground ?? this.hasBackground,
      );

  @override
  PanelAppearance lerp(ThemeExtension<PanelAppearance>? other, double t) {
    if (other is! PanelAppearance) return this;
    return PanelAppearance(
      opacity: (opacity + (other.opacity - opacity) * t),
      hasBackground: t < 0.5 ? hasBackground : other.hasBackground,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light(
    Color primary, {
    required bool hasBackground,
    double panelOpacity = 1,
  }) {
    final hsl = HSLColor.fromColor(primary);
    final accent = hsl.withLightness(hsl.lightness.clamp(0.0, 0.4)).toColor();
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: hasBackground
          ? PageTransitionsTheme(
              builders: {
                ...const PageTransitionsTheme().builders,
                TargetPlatform.android:
                    const PredictiveBackPageTransitionsBuilder(
                      fallbackColor: Colors.transparent,
                    ),
              },
            )
          : null,
      extensions: [
        PanelAppearance(
          opacity: panelOpacity.clamp(0.0, 1.0),
          hasBackground: hasBackground,
        ),
      ],
      scaffoldBackgroundColor: hasBackground
          ? Colors.transparent
          : AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        onPrimary: accent.computeLuminance() > 0.179
            ? Colors.black
            : Colors.white,
        secondary: AppColors.coral,
        surface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: hasBackground ? Colors.transparent : AppColors.canvas,
        foregroundColor: accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
