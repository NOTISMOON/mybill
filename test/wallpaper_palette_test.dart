import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bill/features/profile/data/wallpaper_palette.dart';
import 'package:bill/features/profile/domain/appearance_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallpaper colors follow the original Flutter image scheme', (
    tester,
  ) async {
    const wallpapers = [
      Color(0xFF305AA9),
      Color(0xFFE88445),
      Color(0xFF358B65),
    ];

    for (final wallpaper in wallpapers) {
      final result = await tester.runAsync(() async {
        final bytes = await _solidPng(wallpaper);
        final scheme = await ColorScheme.fromImageProvider(
          provider: MemoryImage(bytes),
          brightness: Brightness.light,
        );
        final palette = await WallpaperPalette.fromBytes(bytes);
        return (scheme: scheme, palette: palette);
      });

      expect(result, isNotNull);
      final scheme = result!.scheme;
      expect(result.palette, {
        AppearanceModule.ledger: scheme.primary,
        AppearanceModule.statistics: scheme.secondary,
        AppearanceModule.editor: scheme.tertiary,
        AppearanceModule.profile: Color.lerp(
          scheme.primary,
          scheme.tertiary,
          0.5,
        ),
        AppearanceModule.navigation: Color.lerp(
          scheme.primary,
          scheme.secondary,
          0.35,
        ),
      });
    }
  });

  testWidgets('restores experimental auto colors and keeps custom colors', (
    tester,
  ) async {
    const custom = Color(0xFFAE3258);
    final result = await tester.runAsync(() async {
      final bytes = await _solidPng(const Color(0xFF305AA9));
      final scheme = await ColorScheme.fromImageProvider(
        provider: MemoryImage(bytes),
        brightness: Brightness.light,
      );
      final savedColors = _experimentalColors(scheme.primary)
        ..[AppearanceModule.editor] = custom;
      final restored = await WallpaperPalette.restorePreviousPalette(
        bytes,
        savedColors,
      );
      final original = await WallpaperPalette.fromBytes(bytes);
      return (savedColors: savedColors, restored: restored, original: original);
    });

    expect(result, isNotNull);
    expect(result!.restored.containsKey(AppearanceModule.editor), isFalse);
    final afterRestore = {...result.savedColors, ...result.restored};
    expect(afterRestore[AppearanceModule.editor], custom);
    for (final module in AppearanceModule.values) {
      if (module == AppearanceModule.editor) continue;
      expect(afterRestore[module], result.original[module]);
    }
  });
}

Future<Uint8List> _solidPng(Color color) async {
  const size = 64;
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64), ui.Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Reconstructs colors saved by the brief experimental palette version.
Map<AppearanceModule, Color> _experimentalColors(Color wallpaperColor) {
  final base = HSLColor.fromColor(wallpaperColor);
  final hue = base.saturation < 0.12 ? 180.0 : base.hue;
  const offsets = <AppearanceModule, double>{
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
        (hue + offsets[module]!) % 360,
        saturation,
        lightness[module]!,
      ),
  };
}

Color _darkAccent(double hue, double saturation, double lightness) {
  var tone = lightness;
  var color = HSLColor.fromAHSL(1, hue, saturation, tone).toColor();
  while (color.computeLuminance() > 0.10 && tone > 0.12) {
    tone -= 0.01;
    color = HSLColor.fromAHSL(1, hue, saturation, tone).toColor();
  }
  return color;
}
