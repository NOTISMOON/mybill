import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/appearance_module.dart';

/// Local appearance preferences. Every module owns its color and panel opacity.
class AppearanceStore extends ChangeNotifier {
  AppearanceStore({this.directory});

  static const schemaVersion = 3;
  static const defaultColor = Color(0xFF123F3A);

  final Directory? directory;
  Map<AppearanceModule, ModuleAppearance> _modules = _defaults();
  Uint8List? _backgroundBytes;
  double _wallpaperOverlayOpacity = 0.20;
  Future<void> _pending = Future<void>.value();
  bool _loaded = false;
  int _temporaryFileId = 0;

  Directory? get storageDirectory => directory;
  ModuleAppearance module(AppearanceModule value) => _modules[value]!;
  double get wallpaperOverlayOpacity => _wallpaperOverlayOpacity;
  Uint8List? get backgroundBytes {
    final bytes = _backgroundBytes;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  Future<void> load() => _serially(_loadFromDisk);

  Future<void> setModuleColor(AppearanceModule module, Color value) =>
      _serially(() async {
        await _ensureLoaded();
        final color = Color(0xFF000000 | (value.toARGB32() & 0x00FFFFFF));
        if (_modules[module]!.color == color) return;
        final next = Map<AppearanceModule, ModuleAppearance>.of(_modules);
        next[module] = next[module]!.copyWith(color: color);
        await _writeConfiguration(
          next,
          _backgroundBytes != null,
          _wallpaperOverlayOpacity,
        );
        _modules = next;
        notifyListeners();
      });

  Future<void> setModuleOpacity(AppearanceModule module, double opacity) =>
      _serially(() async {
        await _ensureLoaded();
        final value = opacity.clamp(0.0, 1.0);
        if (_modules[module]!.panelOpacity == value) return;
        final next = Map<AppearanceModule, ModuleAppearance>.of(_modules);
        next[module] = next[module]!.copyWith(panelOpacity: value);
        await _writeConfiguration(
          next,
          _backgroundBytes != null,
          _wallpaperOverlayOpacity,
        );
        _modules = next;
        notifyListeners();
      });

  Future<void> setWallpaperOverlayOpacity(double opacity) =>
      _serially(() async {
        await _ensureLoaded();
        final value = opacity.clamp(0.0, 1.0);
        if (_wallpaperOverlayOpacity == value) return;
        await _writeConfiguration(_modules, _backgroundBytes != null, value);
        _wallpaperOverlayOpacity = value;
        notifyListeners();
      });

  Future<void> applyPalette(Map<AppearanceModule, Color> palette) =>
      _serially(() async {
        await _ensureLoaded();
        final next = _withPalette(_modules, palette);
        await _writeConfiguration(
          next,
          _backgroundBytes != null,
          _wallpaperOverlayOpacity,
        );
        _modules = next;
        notifyListeners();
      });

  Future<void> setBackground(
    Uint8List bytes, {
    Map<AppearanceModule, Color>? palette,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Background image is empty.');
    }
    final snapshot = Uint8List.fromList(bytes);
    return _serially(() async {
      await _ensureLoaded();
      final next = palette == null ? _modules : _withPalette(_modules, palette);
      await _writeAtomically(await _file('background.img'), snapshot);
      await _writeConfiguration(next, true, _wallpaperOverlayOpacity);
      _modules = next;
      _backgroundBytes = snapshot;
      notifyListeners();
    });
  }

  Future<void> clearBackground() => _serially(() async {
    await _ensureLoaded();
    final imageFile = await _file('background.img');
    if (_backgroundBytes != null) {
      await _writeConfiguration(_modules, false, _wallpaperOverlayOpacity);
      _backgroundBytes = null;
      notifyListeners();
    }
    if (await imageFile.exists()) await imageFile.delete();
  });

  Future<void> _ensureLoaded() async {
    if (!_loaded) await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final file = await _file('appearance.json');
    if (!await file.exists()) {
      await _writeConfiguration(_modules, false, _wallpaperOverlayOpacity);
      _loaded = true;
      notifyListeners();
      return;
    }
    final decoded = _decode(await file.readAsString());
    Uint8List? imageBytes;
    if (decoded.hasBackground) {
      final imageFile = await _file('background.img');
      if (await imageFile.exists()) imageBytes = await imageFile.readAsBytes();
      if (imageBytes?.isEmpty ?? false) imageBytes = null;
    }
    if (decoded.version != schemaVersion ||
        (decoded.hasBackground && imageBytes == null)) {
      await _writeConfiguration(
        decoded.modules,
        imageBytes != null,
        decoded.overlayOpacity,
      );
    }
    _modules = decoded.modules;
    _backgroundBytes = imageBytes;
    _wallpaperOverlayOpacity = decoded.overlayOpacity;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _writeConfiguration(
    Map<AppearanceModule, ModuleAppearance> modules,
    bool hasBackground,
    double overlayOpacity,
  ) async {
    final data = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': schemaVersion,
      'hasBackground': hasBackground,
      'wallpaperOverlayOpacity': overlayOpacity,
      'modules': {
        for (final module in AppearanceModule.values)
          module.storageKey: {
            'color': _colorHex(modules[module]!.color),
            'panelOpacity': modules[module]!.panelOpacity,
          },
      },
    });
    await _writeAtomically(
      await _file('appearance.json'),
      Uint8List.fromList(utf8.encode(data)),
    );
  }

  Future<void> _writeAtomically(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.${_temporaryFileId++}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<File> _file(String name) async {
    final documentsDirectory =
        directory ?? await getApplicationDocumentsDirectory();
    return File('${documentsDirectory.path}${Platform.pathSeparator}$name');
  }

  Future<T> _serially<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Map<AppearanceModule, ModuleAppearance> _defaults() => {
    for (final module in AppearanceModule.values)
      module: ModuleAppearance(
        color: defaultColor,
        panelOpacity: module == AppearanceModule.navigation ? 0.92 : 0.78,
      ),
  };

  static Map<AppearanceModule, ModuleAppearance> _withPalette(
    Map<AppearanceModule, ModuleAppearance> old,
    Map<AppearanceModule, Color> palette,
  ) {
    final next = Map<AppearanceModule, ModuleAppearance>.of(old);
    for (final entry in palette.entries) {
      next[entry.key] = next[entry.key]!.copyWith(
        color: Color(0xFF000000 | (entry.value.toARGB32() & 0x00FFFFFF)),
      );
    }
    return next;
  }

  static ({
    int version,
    Map<AppearanceModule, ModuleAppearance> modules,
    bool hasBackground,
    double overlayOpacity,
  })
  _decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid appearance JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Appearance must be a JSON object.');
    }
    final version = decoded['schemaVersion'];
    if (version == 1 || version == 2) {
      final keys = version == 1
          ? const {'schemaVersion', 'themeColor', 'hasBackground'}
          : const {
              'schemaVersion',
              'themeColor',
              'hasBackground',
              'backgroundOverlayEnabled',
            };
      if (decoded.keys.toSet().difference(keys).isNotEmpty ||
          keys.difference(decoded.keys.toSet()).isNotEmpty ||
          decoded['hasBackground'] is! bool ||
          (version == 2 && decoded['backgroundOverlayEnabled'] is! bool)) {
        throw const FormatException(
          'Appearance has missing or unknown fields.',
        );
      }
      final color = _parseColor(decoded['themeColor']);
      final overlayEnabled =
          version == 1 || decoded['backgroundOverlayEnabled'] == true;
      return (
        version: version as int,
        modules: {
          for (final module in AppearanceModule.values)
            module: ModuleAppearance(
              color: color,
              panelOpacity: module == AppearanceModule.navigation ? 0.97 : 0.94,
            ),
        },
        hasBackground: decoded['hasBackground'] as bool,
        overlayOpacity: overlayEnabled ? 0.76 : 0.0,
      );
    }
    if (version != schemaVersion ||
        decoded.keys.toSet().difference(const {
          'schemaVersion',
          'hasBackground',
          'wallpaperOverlayOpacity',
          'modules',
        }).isNotEmpty ||
        decoded.length != 4 ||
        decoded['hasBackground'] is! bool) {
      throw const FormatException('Appearance has missing or unknown fields.');
    }
    final overlay = _parseOpacity(decoded['wallpaperOverlayOpacity']);
    final rawModules = decoded['modules'];
    if (rawModules is! Map<String, dynamic> ||
        rawModules.length != AppearanceModule.values.length) {
      throw const FormatException('Appearance modules are invalid.');
    }
    final modules = <AppearanceModule, ModuleAppearance>{};
    for (final module in AppearanceModule.values) {
      final raw = rawModules[module.storageKey];
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          !raw.containsKey('color') ||
          !raw.containsKey('panelOpacity')) {
        throw const FormatException('Appearance module is invalid.');
      }
      modules[module] = ModuleAppearance(
        color: _parseColor(raw['color']),
        panelOpacity: _parseOpacity(raw['panelOpacity']),
      );
    }
    return (
      version: version as int,
      modules: modules,
      hasBackground: decoded['hasBackground'] as bool,
      overlayOpacity: overlay,
    );
  }

  static Color _parseColor(Object? value) {
    if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      throw const FormatException('Appearance color must be #RRGGBB.');
    }
    return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
  }

  static double _parseOpacity(Object? value) {
    if (value is! num || !value.isFinite || value < 0 || value > 1) {
      throw const FormatException(
        'Appearance opacity must be between 0 and 1.',
      );
    }
    return value.toDouble();
  }

  static String _colorHex(Color value) =>
      '#${(value.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
