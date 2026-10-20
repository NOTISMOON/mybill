import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../features/profile/data/appearance_store.dart';
import '../features/profile/data/wallpaper_palette.dart';
import '../features/profile/domain/appearance_module.dart';
import 'app_router.dart';
import 'ledger_shell.dart';

class BillApp extends StatefulWidget {
  const BillApp({super.key});

  @override
  State<BillApp> createState() => _BillAppState();
}

class _BillAppState extends State<BillApp> {
  final AppearanceStore appearance = AppearanceStore();
  late Future<void> loading;

  @override
  void initState() {
    super.initState();
    appearance.addListener(refresh);
    loading = _loadAppearance();
  }

  @override
  void dispose() {
    appearance.removeListener(refresh);
    appearance.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAppearance() async {
    await appearance.load();
    final bytes = appearance.backgroundBytes;
    if (bytes == null) return;
    try {
      final current = {
        for (final module in AppearanceModule.values)
          module: appearance.module(module).color,
      };
      final restored = await WallpaperPalette.restorePreviousPalette(
        bytes,
        current,
      );
      if (restored.isNotEmpty) await appearance.applyPalette(restored);
    } catch (_) {
      // A broken image should not prevent the ledger from opening.
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = appearance.backgroundBytes;
    return MaterialApp(
      title: '好好记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        appearance.module(AppearanceModule.ledger).color,
        hasBackground: background != null,
        panelOpacity: appearance.module(AppearanceModule.ledger).panelOpacity,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        if (background == null) return child ?? const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              background,
              fit: BoxFit.cover,
              cacheWidth: 1600,
              gaplessPlayback: true,
            ),
            if (appearance.wallpaperOverlayOpacity > 0)
              ColoredBox(
                color: AppColors.canvas.withValues(
                  alpha: appearance.wallpaperOverlayOpacity,
                ),
              ),
            child ?? const SizedBox.shrink(),
          ],
        );
      },
      home: FutureBuilder<void>(
        future: loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('外观设置读取失败'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => loading = _loadAppearance()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          return LedgerShell(appearance: appearance);
        },
      ),
    );
  }
}
