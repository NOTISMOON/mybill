import 'dart:typed_data';

import 'package:bill/app/app_router.dart';
import 'package:bill/core/theme/app_theme.dart';
import 'package:bill/features/ledger/presentation/entry_editor_page.dart';
import 'package:bill/features/profile/data/appearance_store.dart';
import 'package:bill/features/profile/domain/appearance_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor opens transparently throughout the wallpaper transition', (
    tester,
  ) async {
    final appearance = _WallpaperAppearance();
    addTearDown(appearance.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(
          appearance.module(AppearanceModule.ledger).color,
          hasBackground: true,
        ),
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const Scaffold(body: Center(child: Text('账单'))),
      ),
    );

    navigatorKey.currentState!.pushNamed(
      AppRoutes.entryEditor,
      arguments: EntryEditorRouteArguments(
        appearance: appearance,
        onSave: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final editor = find.byType(EntryEditorPage);
    expect(editor, findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: editor, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, Colors.transparent);

    // On Android, Flutter's default forward transition inserts an opaque
    // ColorScheme.surface scrim while pushing a MaterialPageRoute. With a
    // wallpaper this shows as a white flash before the transparent page lands.
    await tester.pump(const Duration(milliseconds: 100));
    final whiteTransitionBackdrops = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color == Colors.white);
    expect(whiteTransitionBackdrops, isEmpty);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _WallpaperAppearance extends AppearanceStore {
  // The route only needs to know a wallpaper is configured; decoding and disk
  // persistence are covered separately from this widget transition test.
  @override
  Uint8List? get backgroundBytes => Uint8List.fromList([1]);
}
