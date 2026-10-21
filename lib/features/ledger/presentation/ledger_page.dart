import 'package:flutter/material.dart';

import '../../../core/formatters/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/ledger_entry.dart';
import 'widgets/daily_category_group_card.dart';
import 'widgets/month_summary_card.dart';
import 'widgets/principal_editor_dialog.dart';
import 'widgets/total_assets_card.dart';

enum _EntryFilter { all, expense, income }

class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.entries,
    required this.principalCents,
    required this.totalAssetsCents,
    required this.month,
    required this.onMonthChanged,
    required this.onSetPrincipal,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LedgerEntry> entries;
  final int principalCents;
  final int totalAssetsCents;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final Future<void> Function(int) onSetPrincipal;
  final ValueChanged<DateTime> onAdd;
  final ValueChanged<LedgerEntry> onEdit;
  final Future<void> Function(LedgerEntry) onDelete;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _search = TextEditingController();
  _EntryFilter _filter = _EntryFilter.all;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateInMonth(DateTime.now(), widget.month);
    _search.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LedgerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      if (_selectedDate.year != widget.month.year ||
          _selectedDate.month != widget.month.month) {
        _selectedDate = _dateInMonth(_selectedDate, widget.month);
      }
    }
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _shiftMonth(int delta) => widget.onMonthChanged(
    DateTime(widget.month.year, widget.month.month + delta),
  );

  void _selectDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    setState(() => _selectedDate = day);
    if (day.year != widget.month.year || day.month != widget.month.month) {
      widget.onMonthChanged(DateTime(day.year, day.month));
    }
  }

  void _shiftDay(int delta) => _selectDate(
    DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + delta,
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: '选择查看日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) _selectDate(picked);
  }

  Future<void> _editPrincipal() async {
    await showPrincipalEditorDialog(
      context,
      principalCents: widget.principalCents,
      onSave: widget.onSetPrincipal,
    );
  }

  Future<void> _confirmDelete(LedgerEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text(
          '${entry.category} · ${formatCny(entry.amountCents)}\n删除后无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.onDelete(entry);
      _message('已删除记录');
    } catch (error) {
      _message('删除失败：$error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final monthly = widget.entries
        .where(
          (entry) =>
              entry.date.year == widget.month.year &&
              entry.date.month == widget.month.month,
        )
        .toList();
    final income = _sum(monthly, EntryType.income);
    final expense = _sum(monthly, EntryType.expense);
    final daily = monthly
        .where(
          (entry) =>
              entry.date.day == _selectedDate.day &&
              entry.date.month == _selectedDate.month &&
              entry.date.year == _selectedDate.year,
        )
        .toList();
    final query = _search.text.trim().toLowerCase();
    final visible = daily.where((entry) {
      if (_filter == _EntryFilter.expense && entry.type != EntryType.expense) {
        return false;
      }
      if (_filter == _EntryFilter.income && entry.type != EntryType.income) {
        return false;
      }
      if (query.isNotEmpty &&
          !entry.category.toLowerCase().contains(query) &&
          !entry.note.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.id.compareTo(a.id));
    final grouped = <(EntryType, String), List<LedgerEntry>>{};
    for (final entry in visible) {
      grouped.putIfAbsent((entry.type, entry.category), () => []).add(entry);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) {
        final aTypeOrder = a.key.$1 == EntryType.expense ? 0 : 1;
        final bTypeOrder = b.key.$1 == EntryType.expense ? 0 : 1;
        final byType = aTypeOrder.compareTo(bTypeOrder);
        if (byType != 0) return byType;
        final aTotal = a.value.fold<int>(
          0,
          (sum, entry) => sum + entry.amountCents,
        );
        final bTotal = b.value.fold<int>(
          0,
          (sum, entry) => sum + entry.amountCents,
        );
        final byAmount = bTotal.compareTo(aTotal);
        return byAmount != 0 ? byAmount : a.key.$2.compareTo(b.key.$2);
      });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Text(
              '好好记账',
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              '看清每一笔，过好每一天',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 25),
            TotalAssetsCard(
              totalAssetsCents: widget.totalAssetsCents,
              principalCents: widget.principalCents,
              netCashFlowCents: widget.totalAssetsCents - widget.principalCents,
              onEditPrincipal: _editPrincipal,
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Text(
                  '${widget.month.year}年${widget.month.month}月',
                  style: TextStyle(
                    color: AppColors.primary(context),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _monthButton(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
                const SizedBox(width: 8),
                _monthButton(Icons.chevron_right_rounded, () => _shiftMonth(1)),
              ],
            ),
            const SizedBox(height: 16),
            MonthSummaryCard(income: income, expense: expense),
            const SizedBox(height: 28),
            Row(
              children: [
                Text(
                  '当天明细',
                  style: TextStyle(
                    color: AppColors.primary(context),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${visible.length} 笔',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('ledger.previousDay'),
                    tooltip: '前一天',
                    onPressed: () => _shiftDay(-1),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary(context),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('ledger.datePicker'),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_selectedDate.year}年${_selectedDate.month}月'
                          '${_selectedDate.day}日 · ${_weekday(_selectedDate.weekday)}',
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary(context),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('ledger.nextDay'),
                    tooltip: '后一天',
                    onPressed: () => _shiftDay(1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('全部', _EntryFilter.all),
                  const SizedBox(width: 8),
                  _filterChip('支出', _EntryFilter.expense),
                  const SizedBox(width: 8),
                  _filterChip('收入', _EntryFilter.income),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索当天分类或备注',
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.muted,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                filled: true,
                fillColor: AppColors.panel(context),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              _emptyBills(
                noMonthlyEntries: monthly.isEmpty,
                noDailyEntries: daily.isEmpty,
              )
            else
              for (final group in groups) ...[
                DailyCategoryGroupCard(
                  key: ValueKey((
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    group.key.$1,
                    group.key.$2,
                  )),
                  type: group.key.$1,
                  category: group.key.$2,
                  entries: group.value,
                  onEdit: widget.onEdit,
                  onDelete: _confirmDelete,
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onTap) => Material(
    color: AppColors.panel(context),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: AppColors.primary(context)),
      ),
    ),
  );

  Widget _filterChip(String label, _EntryFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      showCheckmark: false,
      backgroundColor: AppColors.panel(context),
      selectedColor: AppColors.primary(context).withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? AppColors.primary(context).withValues(alpha: 0.12)
            : AppColors.line,
      ),
      labelStyle: TextStyle(
        color: selected
            ? AppColors.primary(context)
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7),
    );
  }

  Widget _emptyBills({
    required bool noMonthlyEntries,
    required bool noDailyEntries,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: AppColors.primary(context),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          noMonthlyEntries
              ? '这个月还没有账单'
              : noDailyEntries
              ? '这一天还没有账单'
              : '没有符合条件的记录',
          style: TextStyle(
            color: AppColors.primary(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          noDailyEntries ? '选择其他日期，或记下这一天的第一笔' : '试试调整筛选条件',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        if (noDailyEntries) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => widget.onAdd(_selectedDate),
            icon: const Icon(Icons.add_rounded),
            label: const Text('记一笔'),
          ),
        ],
      ],
    ),
  );
}

int _sum(Iterable<LedgerEntry> entries, EntryType type) => entries
    .where((entry) => entry.type == type)
    .fold(0, (total, entry) => total + entry.amountCents);

String _weekday(int value) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][value - 1];

DateTime _dateInMonth(DateTime preferred, DateTime month) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(
    month.year,
    month.month,
    preferred.day > lastDay ? lastDay : preferred.day,
  );
}
