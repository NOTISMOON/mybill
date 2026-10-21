import 'package:bill/app/app_router.dart';
import 'package:bill/features/ledger/domain/ledger_entry.dart';
import 'package:bill/features/profile/data/appearance_store.dart';
import 'package:bill/features/statistics/domain/monthly_expense_totals.dart';
import 'package:bill/features/statistics/presentation/daily_expense_page.dart';
import 'package:bill/features/statistics/presentation/statistics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily expenses sum only matching month and exclude income', () {
    final totals = monthlyExpenseTotals(DateTime(2024, 2), [
      _entry('a', EntryType.expense, 1200, DateTime(2024, 2, 1)),
      _entry('b', EntryType.expense, 800, DateTime(2024, 2, 1)),
      _entry('c', EntryType.income, 5000, DateTime(2024, 2, 1)),
      _entry('d', EntryType.expense, 700, DateTime(2024, 1, 1)),
      _entry('e', EntryType.expense, 300, DateTime(2024, 2, 29)),
    ]);

    expect(totals.length, 29);
    expect(totals[0], 2000);
    expect(totals[1], 0);
    expect(totals[28], 300);
  });

  testWidgets('expense destination opens selected month daily totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appearance = AppearanceStore();
    addTearDown(appearance.dispose);
    final month = DateTime(2024, 2);
    final entries = [
      _entry('a', EntryType.expense, 1200, DateTime(2024, 2, 1)),
      _entry('b', EntryType.expense, 800, DateTime(2024, 2, 1)),
      _entry('c', EntryType.income, 5000, DateTime(2024, 2, 1)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: StatisticsPage(
              entries: entries,
              month: month,
              onMonthChanged: (_) {},
              onOpenMonth: (_) {},
              onOpenDailyExpense: (value) => Navigator.of(context).pushNamed(
                AppRoutes.dailyExpense,
                arguments: DailyExpenseRouteArguments(
                  month: value,
                  entries: entries,
                  appearance: appearance,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('statistics.expenseDestination')),
    );
    await tester.tap(find.text('支出去向'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyExpensePage), findsOneWidget);
    expect(find.text('2024年2月支出总额'), findsOneWidget);
    expect(find.text('¥20.00'), findsWidgets);
    expect(find.text('¥0.00'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('statistics.expenseDay.29')),
      500,
    );
    expect(find.byKey(const Key('statistics.expenseDay.29')), findsOneWidget);
  });
}

LedgerEntry _entry(String id, EntryType type, int cents, DateTime date) =>
    LedgerEntry(
      id: id,
      type: type,
      amountCents: cents,
      category: '餐饮',
      date: date,
      note: '',
    );
