import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/appearance_store.dart';
import '../data/wallpaper_palette.dart';
import '../domain/appearance_module.dart';

class AppearancePreferencesPage extends StatefulWidget {
  const AppearancePreferencesPage({super.key, required this.appearance});

  final AppearanceStore appearance;

  @override
  State<AppearancePreferencesPage> createState() =>
      _AppearancePreferencesPageState();
}

class _AppearancePreferencesPageState extends State<AppearancePreferencesPage> {
  bool _working = false;

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _chooseWallpaper() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (size != null && size > 10 * 1024 * 1024) {
        throw const FormatException('图片不能超过 10 MB');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('图片为空或超过 10 MB');
      }
      await _validateImage(bytes);
      final palette = await WallpaperPalette.fromBytes(bytes);
      await widget.appearance.setBackground(bytes, palette: palette);
      _message('壁纸与模块配色已更新');
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('图片读取或配色失败，请换一张图片重试');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reapplyPalette() async {
    final bytes = widget.appearance.backgroundBytes;
    if (bytes == null || _working) return;
    setState(() => _working = true);
    try {
      await widget.appearance.applyPalette(
        await WallpaperPalette.fromBytes(bytes),
      );
      _message('已重新按壁纸配色');
    } catch (_) {
      _message('自动配色失败');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeWallpaper() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await widget.appearance.clearBackground();
    } catch (_) {
      _message('移除壁纸失败');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _chooseColor(AppearanceModule module) async {
    final initial = widget.appearance.module(module).color;
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorDialog(initial: initial, module: module),
    );
    if (selected == null) return;
    try {
      await widget.appearance.setModuleColor(module, selected);
    } catch (_) {
      _message('颜色保存失败');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.appearance,
    builder: (context, _) {
      final background = widget.appearance.backgroundBytes;
      return Scaffold(
        appBar: AppBar(title: const Text('外观偏好')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '壁纸',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '选择后会自动为各模块搭配颜色，仍可逐项修改。',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 156,
                          width: double.infinity,
                          child: background == null
                              ? ColoredBox(
                                  color: AppColors.primary(
                                    context,
                                  ).withValues(alpha: 0.10),
                                  child: const Center(child: Text('尚未选择壁纸')),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      background,
                                      fit: BoxFit.cover,
                                      cacheWidth: 640,
                                    ),
                                    ColoredBox(
                                      color: AppColors.canvas.withValues(
                                        alpha: widget
                                            .appearance
                                            .wallpaperOverlayOpacity,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _working ? null : _chooseWallpaper,
                            icon: const Icon(Icons.wallpaper_rounded),
                            label: Text(background == null ? '选择壁纸' : '更换壁纸'),
                          ),
                          if (background != null) ...[
                            OutlinedButton(
                              onPressed: _working ? null : _reapplyPalette,
                              child: const Text('重新按壁纸配色'),
                            ),
                            TextButton(
                              onPressed: _working ? null : _removeWallpaper,
                              child: const Text('移除壁纸'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      _OpacityControl(
                        label: '壁纸遮罩',
                        value: widget.appearance.wallpaperOverlayOpacity,
                        enabled: background != null && !_working,
                        onChanged: (value) async {
                          try {
                            await widget.appearance.setWallpaperOverlayOpacity(
                              value,
                            );
                          } catch (_) {
                            _message('遮罩强度保存失败');
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '模块外观',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(context),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '每个模块的颜色和面板透明度独立保存；文字与图标始终保持实色。',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final module in AppearanceModule.values) ...[
                  _ModuleCard(
                    module: module,
                    appearance: widget.appearance.module(module),
                    onColor: () => _chooseColor(module),
                    onOpacity: (value) async {
                      try {
                        await widget.appearance.setModuleOpacity(module, value);
                      } catch (_) {
                        _message('透明度保存失败');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.panel(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.appearance,
    required this.onColor,
    required this.onOpacity,
  });
  final AppearanceModule module;
  final ModuleAppearance appearance;
  final VoidCallback onColor;
  final Future<void> Function(double) onOpacity;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: appearance.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                module.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(onPressed: onColor, child: const Text('调整颜色')),
          ],
        ),
        _OpacityControl(
          label: '面板不透明度',
          value: appearance.panelOpacity,
          enabled: true,
          onChanged: onOpacity,
        ),
      ],
    ),
  );
}

class _OpacityControl extends StatefulWidget {
  const _OpacityControl({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final double value;
  final bool enabled;
  final Future<void> Function(double) onChanged;

  @override
  State<_OpacityControl> createState() => _OpacityControlState();
}

class _OpacityControlState extends State<_OpacityControl> {
  late double _current = widget.value;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _OpacityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _current = widget.value;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(widget.label)),
          Text('${(_current * 100).round()}%'),
        ],
      ),
      Slider(
        value: _current.clamp(0.0, 1.0),
        onChangeStart: widget.enabled ? (_) => _dragging = true : null,
        onChanged: widget.enabled
            ? (value) => setState(() => _current = value)
            : null,
        onChangeEnd: widget.enabled
            ? (value) {
                _dragging = false;
                widget.onChanged(value);
              }
            : null,
        divisions: 20,
      ),
    ],
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial, required this.module});
  final Color initial;
  final AppearanceModule module;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color chosen = widget.initial;
  late final TextEditingController hex = TextEditingController(
    text: _hex(widget.initial),
  );
  String? error;

  static const presets = <Color>[
    Color(0xFF123F3A),
    Color(0xFF286B91),
    Color(0xFFB9574B),
    Color(0xFF755781),
    Color(0xFF8A654B),
    Color(0xFF37444F),
  ];

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void pick(Color color) => setState(() {
    chosen = color;
    hex.text = _hex(color);
    error = null;
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.module.label}颜色'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 9,
            children: [
              for (final color in presets)
                IconButton(
                  tooltip: _hex(color),
                  onPressed: () => pick(color),
                  icon: Icon(Icons.circle, color: color, size: 32),
                ),
            ],
          ),
          TextField(
            controller: hex,
            decoration: InputDecoration(
              labelText: '颜色值 #RRGGBB',
              errorText: error,
            ),
            onChanged: (value) {
              final parsed = _parseHex(value);
              if (parsed != null) setState(() => chosen = parsed);
            },
          ),
          const SizedBox(height: 12),
          Slider(
            value: HSVColor.fromColor(chosen).hue,
            min: 0,
            max: 360,
            onChanged: (value) =>
                pick(HSVColor.fromAHSV(1, value, 0.58, 0.68).toColor()),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final color = _parseHex(hex.text);
          if (color == null) {
            setState(() => error = '请输入 #RRGGBB');
            return;
          }
          Navigator.pop(context, color);
        },
        child: const Text('应用颜色'),
      ),
    ],
  );
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? _parseHex(String value) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}

Future<void> _validateImage(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.FrameInfo? frame;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 64 * 1024 * 1024) {
      throw const FormatException('图片分辨率过高');
    }
    codec = await descriptor.instantiateCodec(
      targetWidth: 64,
      targetHeight: 64,
    );
    frame = await codec.getNextFrame();
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('图片无法解码，请选择 JPG、PNG 或 WebP');
  } finally {
    frame?.image.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
