import 'package:bill/app/widgets/capsule_navigation_bar.dart';
import 'package:bill/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capsule navigation switches tabs on a phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(const Color(0xFF123F3A), hasBackground: false),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            extendBody: true,
            body: Center(child: Text('页面 $selected')),
            bottomNavigationBar: CapsuleNavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (value) =>
                  setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('页面 0'), findsOneWidget);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('页面 1'), findsOneWidget);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('页面 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
