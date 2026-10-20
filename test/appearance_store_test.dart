import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bill/features/profile/data/appearance_store.dart';
import 'package:bill/features/profile/domain/appearance_module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('appearance-test-');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('first load creates module settings in JSON', () async {
    final store = AppearanceStore(directory: directory);
    await store.load();
    final data =
        jsonDecode(
              await File('${directory.path}/appearance.json').readAsString(),
            )
            as Map<String, dynamic>;
    expect(data['schemaVersion'], 3);
    expect(data['wallpaperOverlayOpacity'], 0.2);
    expect((data['modules'] as Map).length, 5);
    expect(
      store.module(AppearanceModule.ledger).color,
      AppearanceStore.defaultColor,
    );
    store.dispose();
  });

  test('module colors and opacity persist independently', () async {
    final store = AppearanceStore(directory: directory);
    await store.load();
    await store.setModuleColor(
      AppearanceModule.statistics,
      const Color(0x80286B91),
    );
    await store.setModuleOpacity(AppearanceModule.statistics, 0.35);
    await store.setWallpaperOverlayOpacity(0);
    final image = Uint8List.fromList([1, 2, 3]);
    await store.setBackground(
      image,
      palette: {AppearanceModule.ledger: const Color(0xFF995544)},
    );
    image[0] = 99;

    final restored = AppearanceStore(directory: directory);
    await restored.load();
    expect(
      restored.module(AppearanceModule.statistics).color,
      const Color(0xFF286B91),
    );
    expect(restored.module(AppearanceModule.statistics).panelOpacity, 0.35);
    expect(
      restored.module(AppearanceModule.ledger).color,
      const Color(0xFF995544),
    );
    expect(
      restored.module(AppearanceModule.profile).color,
      AppearanceStore.defaultColor,
    );
    expect(restored.wallpaperOverlayOpacity, 0);
    expect(restored.backgroundBytes, [1, 2, 3]);
    await restored.clearBackground();
    expect(restored.backgroundBytes, isNull);
    expect(await File('${directory.path}/background.img').exists(), isFalse);
    store.dispose();
    restored.dispose();
  });

  test(
    'version 2 settings migrate without losing wallpaper or overlay',
    () async {
      final file = File('${directory.path}/appearance.json');
      await file.writeAsString(
        jsonEncode({
          'schemaVersion': 2,
          'themeColor': '#286B91',
          'hasBackground': true,
          'backgroundOverlayEnabled': false,
        }),
      );
      await File('${directory.path}/background.img').writeAsBytes([5, 6]);
      final store = AppearanceStore(directory: directory);
      await store.load();
      expect(store.backgroundBytes, [5, 6]);
      expect(store.wallpaperOverlayOpacity, 0);
      for (final module in AppearanceModule.values) {
        expect(store.module(module).color, const Color(0xFF286B91));
      }
      final migrated = jsonDecode(await file.readAsString());
      expect(migrated['schemaVersion'], 3);
      store.dispose();
    },
  );

  test('version 1 stale image flag is repaired', () async {
    final file = File('${directory.path}/appearance.json');
    await file.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'themeColor': '#ABCDEF',
        'hasBackground': true,
      }),
    );
    final store = AppearanceStore(directory: directory);
    await store.load();
    expect(store.backgroundBytes, isNull);
    expect(store.wallpaperOverlayOpacity, 0.76);
    final migrated = jsonDecode(await file.readAsString());
    expect(migrated['hasBackground'], isFalse);
    expect(migrated['schemaVersion'], 3);
    store.dispose();
  });

  test('invalid settings are not overwritten', () async {
    final file = File('${directory.path}/appearance.json');
    const invalid = '{"schemaVersion":3,"modules":{}}';
    await file.writeAsString(invalid);
    final store = AppearanceStore(directory: directory);
    await expectLater(store.load(), throwsFormatException);
    expect(await file.readAsString(), invalid);
    store.dispose();
  });
}
