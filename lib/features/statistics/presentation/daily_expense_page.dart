import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../../ledger/domain/ledger_entry.dart';
import '../domain/monthly_expense_totals.dart';

class DailyExpensePage extends StatelessWidget {
  const DailyExpensePage({
    super.key,
    required this.month,
    required this.entries,
  });

  final DateTime month;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final totals = monthlyExpenseTotals(month, entries);
    final monthTotal = totals.fold<int>(0, (sum, amount) => sum + amount);
    final highest = totals.fold<int>(0, math.max);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('每日支出')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.panel(context),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${month.year}年${month.month}月支出总额',
                        style: TextStyle(color: primary, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatCny(monthTotal),
                        style: TextStyle(
                          color: primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '共 ${totals.where((amount) => amount > 0).length} 天有支出',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '每日明细',
                  style: TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < totals.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _DayExpenseRow(
                    key: Key('statistics.expenseDay.${index + 1}'),
                    date: DateTime(month.year, month.month, index + 1),
                    amountCents: totals[index],
                    highestCents: highest,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayExpenseRow extends StatelessWidget {
  const _DayExpenseRow({
    super.key,
    required this.date,
    required this.amountCents,
    required this.highestCents,
  });

  final DateTime date;
  final int amountCents;
  final int highestCents;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${date.month}月${date.day}日',
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '周${weekdays[date.weekday - 1]}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                formatCny(amountCents),
                style: TextStyle(
                  color: amountCents == 0 ? AppColors.muted : AppColors.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (amountCents > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: highestCents == 0 ? 0 : amountCents / highestCents,
                minHeight: 5,
                backgroundColor: primary.withValues(alpha: 0.08),
                color: AppColors.coral,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
