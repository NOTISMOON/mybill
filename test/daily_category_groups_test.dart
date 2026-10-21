import 'package:bill/features/ledger/domain/ledger_entry.dart';
import 'package:bill/features/ledger/presentation/ledger_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only the selected day is grouped by category and details edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final step = today.day == 1 ? 1 : -1;
    final otherDay = DateTime(today.year, today.month, today.day + step);
    final entries = [
      _entry('meal-lunch', EntryType.expense, 1200, '餐饮', today, '午餐'),
      _entry('meal-dinner', EntryType.expense, 800, '餐饮', today, '晚餐'),
      _entry('transport', EntryType.expense, 500, '交通', today, '地铁'),
      _entry('salary', EntryType.income, 3000, '工资', today, '兼职'),
      _entry('other-day', EntryType.expense, 100, '餐饮', otherDay, '旧账'),
    ];
    LedgerEntry? edited;
    DateTime? addDate;
    DateTime month = DateTime(today.year, today.month);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: LedgerPage(
              entries: entries,
              principalCents: 0,
              totalAssetsCents: 0,
              month: month,
              onMonthChanged: (value) => setState(() => month = value),
              onSetPrincipal: (_) async {},
              onAdd: (date) => addDate = date,
              onEdit: (entry) => edited = entry,
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('支出 · 2 笔'), findsOneWidget);
    expect(find.text('-¥20.00'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);
    expect(find.text('旧账'), findsNothing);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);
    await tester.tap(find.text('午餐'));
    expect(edited?.id, 'meal-lunch');

    await tester.tap(
      find.byKey(Key(step == 1 ? 'ledger.nextDay' : 'ledger.previousDay')),
    );
    await tester.pumpAndSettle();
    expect(find.text('午餐'), findsNothing);
    expect(find.text('支出 · 1 笔'), findsOneWidget);
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('旧账'), findsOneWidget);

    await tester.tap(
      find.byKey(Key(step == 1 ? 'ledger.nextDay' : 'ledger.previousDay')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记一笔'));
    expect(addDate, DateTime(today.year, today.month, today.day + step * 2));
  });
}

LedgerEntry _entry(
  String id,
  EntryType type,
  int amountCents,
  String category,
  DateTime date,
  String note,
) => LedgerEntry(
  id: id,
  type: type,
  amountCents: amountCents,
  category: category,
  date: date,
  note: note,
);
