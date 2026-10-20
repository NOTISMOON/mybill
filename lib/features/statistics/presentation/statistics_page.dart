import 'dart:math' as math;

import 'package:bill/features/ledger/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:bill/core/theme/app_theme.dart';

const _coral = Color(0xFFE87D62);
const _muted = Color(0xFF73867F);
const _hairline = Color(0xFFE8EEEA);

enum _Period { month, year }

/// Monthly and yearly summaries for an already loaded personal ledger.
///
/// [month] is the selected month even while the yearly view is open. The parent
/// owns date navigation; this widget only owns the month/year display choice.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.entries,
    required this.month,
    required this.onMonthChanged,
    required this.onOpenMonth,
  });

  final List<LedgerEntry> entries;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  _Period _period = _Period.month;

  void _movePeriod(int direction) {
    final date = widget.month;
    widget.onMonthChanged(
      _period == _Period.month
          ? DateTime(date.year, date.month + direction, 1)
          : DateTime(date.year + direction, date.month, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.month.year;
    final month = widget.month.month;
    final selectedEntries = widget.entries.where(
      (entry) =>
          entry.date.year == year &&
          (_period == _Period.year || entry.date.month == month),
    );
    final totals = _Totals();
    for (final entry in selectedEntries) {
      totals.add(entry);
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildPeriodPicker(),
              const SizedBox(height: 20),
              _buildDatePicker(),
              const SizedBox(height: 22),
              _OverviewCard(
                title: _period == _Period.month ? '本月结余' : '全年结余',
                totals: totals,
              ),
              const SizedBox(height: 24),
              if (_period == _Period.month)
                ..._buildMonthContent(year, month, totals)
              else
                ..._buildYearContent(year, totals),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '账单统计',
        style: TextStyle(
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 8),
      const Text('每一笔日常，都有迹可循', style: TextStyle(color: _muted, fontSize: 14)),
    ],
  );

  Widget _buildPeriodPicker() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: AppColors.panel(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        _periodButton(_Period.month, '月度'),
        _periodButton(_Period.year, '年度'),
      ],
    ),
  );

  Widget _periodButton(_Period period, String label) {
    final selected = _period == period;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _period = period),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.panel(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : _muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final date = widget.month;
    final title = _period == _Period.month
        ? '${date.year}年 ${date.month.toString().padLeft(2, '0')}月'
        : '${date.year}年';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: _period == _Period.month ? '上个月' : '上一年',
          onPressed: () => _movePeriod(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          color: Theme.of(context).colorScheme.primary,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: _period == _Period.month ? '下个月' : '下一年',
          onPressed: () => _movePeriod(1),
          icon: const Icon(Icons.chevron_right_rounded),
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  List<Widget> _buildMonthContent(int year, int month, _Totals totals) {
    final categoryColors = [
      _coral,
      Theme.of(context).colorScheme.primary,
      const Color(0xFFE8B877),
      const Color(0xFF87A9BF),
      const Color(0xFFA794B8),
      const Color(0xFFBB9F89),
    ];
    final categories = <String, int>{};
    final dayCount = DateTime(year, month + 1, 0).day;
    final dailyIncome = List<int>.filled(dayCount, 0);
    final dailyExpense = List<int>.filled(dayCount, 0);

    for (final entry in widget.entries) {
      if (entry.date.year != year || entry.date.month != month) continue;
      final dayIndex = entry.date.day - 1;
      if (entry.type == EntryType.expense) {
        categories.update(
          entry.category,
          (amount) => amount + entry.amountCents,
          ifAbsent: () => entry.amountCents,
        );
        dailyExpense[dayIndex] += entry.amountCents;
      } else {
        dailyIncome[dayIndex] += entry.amountCents;
      }
    }

    final sortedCategories = categories.entries.toList()
      ..sort((a, b) {
        final amountOrder = b.value.compareTo(a.value);
        return amountOrder != 0 ? amountOrder : a.key.compareTo(b.key);
      });

    return [
      if (totals.isEmpty) ...[
        const _EmptyHint(text: '这个月还没有账目，记下一笔后就能看到分析。'),
        const SizedBox(height: 24),
      ],
      _Panel(
        title: '支出去向',
        subtitle: '按分类查看本月花费',
        child: sortedCategories.isEmpty
            ? const _PanelEmpty(
                icon: Icons.pie_chart_outline_rounded,
                message: '暂无支出分类',
              )
            : Column(
                children: [
                  for (var i = 0; i < sortedCategories.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    _CategoryRow(
                      category: sortedCategories[i].key,
                      amountCents: sortedCategories[i].value,
                      totalCents: totals.expense,
                      color: categoryColors[i % categoryColors.length],
                    ),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: '每日收支',
        subtitle: '看看钱都流向了哪一天',
        child: totals.isEmpty
            ? const _PanelEmpty(
                icon: Icons.show_chart_rounded,
                message: '记录后可查看每日趋势',
              )
            : _DailyTrend(income: dailyIncome, expense: dailyExpense),
      ),
    ];
  }

  List<Widget> _buildYearContent(int year, _Totals totals) {
    final months = List.generate(12, (_) => _Totals());
    for (final entry in widget.entries) {
      if (entry.date.year == year) {
        months[entry.date.month - 1].add(entry);
      }
    }
    final highestMonth = months.fold<int>(
      0,
      (highest, month) =>
          math.max(highest, math.max(month.income, month.expense)),
    );

    return [
      if (totals.isEmpty) ...[
        const _EmptyHint(text: '这一年还没有账目，从任意月份开始记录吧。'),
        const SizedBox(height: 24),
      ],
      _Panel(
        title: '12个月收支',
        subtitle: '点选月份，查看详细统计',
        child: Column(
          children: [
            const _ChartLegend(),
            const SizedBox(height: 18),
            for (var i = 0; i < 12; i++) ...[
              if (i > 0) const Divider(height: 25, color: _hairline),
              _YearMonthRow(
                month: i + 1,
                totals: months[i],
                maxAmount: highestMonth,
                onTap: () {
                  setState(() => _period = _Period.month);
                  widget.onOpenMonth(DateTime(year, i + 1, 1));
                },
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _Totals {
  int income = 0;
  int expense = 0;

  int get balance => income - expense;
  bool get isEmpty => income == 0 && expense == 0;

  void add(LedgerEntry entry) {
    if (entry.type == EntryType.income) {
      income += entry.amountCents;
    } else {
      expense += entry.amountCents;
    }
  }
}

String _money(int amountCents) {
  final absolute = amountCents.abs();
  final yuan = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  final withCommas = yuan.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${amountCents < 0 ? '-' : ''}¥$withCommas.$cents';
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.title, required this.totals});

  final String title;
  final _Totals totals;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      color: AppColors.accentPanel(context),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: -92,
          right: -70,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.045),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: 44,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.07),
                width: 26,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(totals.balance),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Divider(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.17),
                height: 1,
              ),
              const SizedBox(height: 21),
              Row(
                children: [
                  Expanded(
                    child: _HeroAmount(
                      label: '收入',
                      amountCents: totals.income,
                      icon: Icons.south_west_rounded,
                      iconColor: const Color(0xFFAADDC8),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.17),
                  ),
                  Expanded(
                    child: _HeroAmount(
                      label: '支出',
                      amountCents: totals.expense,
                      icon: Icons.north_east_rounded,
                      iconColor: const Color(0xFFFFB8A6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.label,
    required this.amountCents,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int amountCents;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.70),
              fontSize: 13,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          _money(amountCents),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 21, 20, 22),
    decoration: BoxDecoration(
      color: AppColors.panel(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF0F1ED)),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.035),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.panel(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: _coral, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 118,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30, color: const Color(0xFFB9C8C0)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: _muted, fontSize: 13)),
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amountCents,
    required this.totalCents,
    required this.color,
  });

  final String category;
  final int amountCents;
  final int totalCents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final proportion = totalCents == 0 ? 0.0 : amountCents / totalCents;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                category.characters.first,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _money(amountCents),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: proportion.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F3F0),
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(proportion * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _LegendItem(color: Theme.of(context).colorScheme.primary, label: '收入'),
      const SizedBox(width: 18),
      const _LegendItem(color: _coral, label: '支出'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    ],
  );
}

class _DailyTrend extends StatelessWidget {
  const _DailyTrend({required this.income, required this.expense});

  final List<int> income;
  final List<int> expense;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _ChartLegend(),
      const SizedBox(height: 18),
      Semantics(
        label:
            '每日收支趋势，收入${_money(income.fold(0, (a, b) => a + b))}，'
            '支出${_money(expense.fold(0, (a, b) => a + b))}',
        child: SizedBox(
          height: 132,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              income: income,
              expense: expense,
              incomeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in [1, 8, 15, 22, income.length])
            Text('$day日', style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ],
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.income,
    required this.expense,
    required this.incomeColor,
  });

  final List<int> income;
  final List<int> expense;
  final Color incomeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final bottom = size.height - 7;
    final chartHeight = bottom - top;
    final grid = Paint()
      ..color = _hairline
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = bottom - chartHeight * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    var maxAmount = 1;
    for (final value in [...income, ...expense]) {
      maxAmount = math.max(maxAmount, value);
    }
    _drawSeries(canvas, size, income, maxAmount, incomeColor, top, bottom);
    _drawSeries(canvas, size, expense, maxAmount, _coral, top, bottom);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<int> values,
    int maxAmount,
    Color color,
    double top,
    double bottom,
  ) {
    if (values.isEmpty) return;
    final path = Path();
    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = bottom - (values[i] / maxAmount) * (bottom - top);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.5,
    );
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final x = step * i;
      final y = bottom - (values[i] / maxAmount) * (bottom - top);
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.income != income ||
      oldDelegate.expense != expense ||
      oldDelegate.incomeColor != incomeColor;
}

class _YearMonthRow extends StatelessWidget {
  const _YearMonthRow({
    required this.month,
    required this.totals,
    required this.maxAmount,
    required this.onTap,
  });

  final int month;
  final _Totals totals;
  final int maxAmount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$month月，收入${_money(totals.income)}，支出${_money(totals.expense)}',
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '${month.toString().padLeft(2, '0')}月',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  _YearBar(
                    value: totals.income,
                    maximum: maxAmount,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 7),
                  _YearBar(
                    value: totals.expense,
                    maximum: maxAmount,
                    color: _coral,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(totals.income),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _money(totals.expense),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
          ],
        ),
      ),
    ),
  );
}

class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  final int value;
  final int maximum;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: maximum == 0 ? 0 : value / maximum,
      minHeight: 6,
      backgroundColor: const Color(0xFFF1F3F0),
      color: color,
    ),
  );
}
