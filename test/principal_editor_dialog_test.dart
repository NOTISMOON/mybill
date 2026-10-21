import 'package:bill/features/ledger/presentation/widgets/principal_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('本金按分保存，拒绝超过两位小数，也允许零元', (tester) async {
    int? savedCents;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPrincipalEditorDialog(
                context,
                principalCents: 0,
                onSave: (cents) async {
                  savedCents = cents;
                },
              ),
              child: const Text('编辑本金'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('编辑本金'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12.345');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(savedCents, isNull);
    expect(find.textContaining('最多保留两位小数'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12.34');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(savedCents, 1234);

    await tester.tap(find.text('编辑本金'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(savedCents, 0);
  });
}
