import 'package:flutter/material.dart';

import '../../../core/formatters/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/ledger_entry.dart';
import 'widgets/entry_tile.dart';
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
  final VoidCallback onAdd;
  final ValueChanged<LedgerEntry> onEdit;
  final Future<void> Function(LedgerEntry) onDelete;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _search = TextEditingController();
  _EntryFilter _filter = _EntryFilter.all;
  String? _category;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LedgerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _category = null;
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
    final categories = monthly.map((entry) => entry.category).toSet().toList()
      ..sort();
    final query = _search.text.trim().toLowerCase();
    final visible =
        monthly.where((entry) {
          if (_filter == _EntryFilter.expense &&
              entry.type != EntryType.expense) {
            return false;
          }
          if (_filter == _EntryFilter.income &&
              entry.type != EntryType.income) {
            return false;
          }
          if (_category != null && entry.category != _category) {
            return false;
          }
          if (query.isNotEmpty &&
              !entry.category.toLowerCase().contains(query) &&
              !entry.note.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
    final grouped = <DateTime, List<LedgerEntry>>{};
    for (final entry in visible) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      grouped.putIfAbsent(day, () => []).add(entry);
    }

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
                  '收支明细',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('全部', _EntryFilter.all),
                  const SizedBox(width: 8),
                  _filterChip('支出', _EntryFilter.expense),
                  const SizedBox(width: 8),
                  _filterChip('收入', _EntryFilter.income),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(
                      () => _category = value == '__all__' ? null : value,
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: '__all__',
                        child: Text('全部分类'),
                      ),
                      ...categories.map(
                        (value) =>
                            PopupMenuItem(value: value, child: Text(value)),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.panel(context),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _category ?? '分类',
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.muted,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索分类或备注',
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
              _emptyBills(monthly.isEmpty)
            else
              for (final group in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
                  child: Row(
                    children: [
                      Text(
                        '${group.key.month}月${group.key.day}日',
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _weekday(group.key.weekday),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.panel(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < group.value.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 66),
                            child: Divider(height: 1, color: AppColors.line),
                          ),
                        EntryTile(
                          entry: group.value[i],
                          onEdit: () => widget.onEdit(group.value[i]),
                          onDelete: () => _confirmDelete(group.value[i]),
                        ),
                      ],
                    ],
                  ),
                ),
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

  Widget _emptyBills(bool noMonthlyEntries) => Padding(
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
          noMonthlyEntries ? '这个月还没有账单' : '没有符合条件的记录',
          style: TextStyle(
            color: AppColors.primary(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          noMonthlyEntries ? '从记下第一笔开始吧' : '试试调整筛选条件',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        if (noMonthlyEntries) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.onAdd,
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
