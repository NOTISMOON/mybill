import 'package:bill/core/theme/app_theme.dart';
import 'package:bill/features/profile/data/appearance_store.dart';
import 'package:bill/features/profile/presentation/appearance_preferences_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('appearance page shows independent module controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppearanceStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(
          AppearanceStore.defaultColor,
          hasBackground: false,
        ),
        home: AppearancePreferencesPage(appearance: store),
      ),
    );
    expect(find.text('外观偏好'), findsOneWidget);
    expect(find.text('模块外观'), findsOneWidget);
    expect(find.text('账单'), findsOneWidget);
    await tester.ensureVisible(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('调整颜色'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
