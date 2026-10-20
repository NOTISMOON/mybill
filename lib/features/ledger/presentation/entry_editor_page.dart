import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bill/features/ledger/domain/ledger_entry.dart';
import 'package:bill/core/theme/app_theme.dart';

/// A page for adding or editing one ledger entry.
///
/// Push this widget as a route and pass [onSave] (usually LedgerStore.upsert).
/// The route closes only after the save finishes successfully.
class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, this.initial, required this.onSave});

  final LedgerEntry? initial;
  final Future<void> Function(LedgerEntry) onSave;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  static const _accent = Color(0xFFE87D62);
  static const _muted = Color(0xFF72847E);
  static const _border = Color(0xFFE5EAE4);

  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _onPrimary => Theme.of(context).colorScheme.onPrimary;

  static const _expenses = <_Category>[
    _Category('餐饮', Icons.restaurant_rounded),
    _Category('交通', Icons.directions_bus_rounded),
    _Category('购物', Icons.shopping_bag_rounded),
    _Category('居家', Icons.home_rounded),
    _Category('娱乐', Icons.movie_rounded),
    _Category('医疗', Icons.medical_services_rounded),
    _Category('学习', Icons.menu_book_rounded),
    _Category('其他', Icons.more_horiz_rounded),
  ];

  static const _incomes = <_Category>[
    _Category('工资', Icons.work_rounded),
    _Category('奖金', Icons.card_giftcard_rounded),
    _Category('理财', Icons.trending_up_rounded),
    _Category('兼职', Icons.laptop_rounded),
    _Category('其他', Icons.more_horiz_rounded),
  ];

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late EntryType _type;
  late String _category;
  late DateTime _date;
  String? _amountError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? EntryType.expense;
    _category = initial?.category ?? _expenses.first.name;
    _date = initial?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: initial == null ? '' : _formatCentsForInput(initial.amountCents),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _formatCentsForInput(int cents) {
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '$whole.$fraction';
  }

  /// Parses the decimal text directly; no floating point arithmetic is used.
  static int? _parseAmountCents(String input) {
    final value = input.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(value);
    if (match == null) return null;
    final centsText =
        '${match.group(1)}${(match.group(2) ?? '').padRight(2, '0')}';
    final cents = int.tryParse(centsText);
    return cents != null && cents > 0 ? cents : null;
  }

  void _changeType(EntryType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _category = (type == EntryType.expense ? _expenses : _incomes).first.name;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year < 2000 ? _date.year : 2000),
      lastDate: DateTime(_date.year > 2100 ? _date.year : 2100, 12, 31),
      helpText: '选择账单日期',
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amountCents = _parseAmountCents(_amountController.text);
    if (amountCents == null) {
      setState(() => _amountError = '请输入大于 0 的金额，最多保留两位小数');
      return;
    }

    final entry = LedgerEntry(
      id:
          widget.initial?.id ??
          DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36),
      type: _type,
      amountCents: amountCents,
      category: _category,
      date: DateTime(_date.year, _date.month, _date.day),
      note: _noteController.text.trim(),
    );

    setState(() {
      _amountError = null;
      _saving = true;
    });
    try {
      await widget.onSave(entry);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试。')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final isExpense = _type == EntryType.expense;
    final categories = isExpense ? _expenses : _incomes;
    final visibleCategories = categories.any((item) => item.name == _category)
        ? categories
        : [_Category(_category, Icons.label_rounded), ...categories];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: _primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          widget.initial == null ? '记一笔' : '编辑账单',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '记录今天，也看见生活',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '简单记下每一笔，月度和年度账单会自动汇总。',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 25),
                  _typeSelector(isExpense),
                  const SizedBox(height: 16),
                  _amountCard(isExpense),
                  const SizedBox(height: 27),
                  _sectionTitle('分类', '这笔钱花在了哪里？'),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final category in visibleCategories)
                        _categoryChip(category, isExpense),
                    ],
                  ),
                  const SizedBox(height: 27),
                  _sectionTitle('日期', '按实际发生日期记录'),
                  const SizedBox(height: 12),
                  _datePicker(),
                  const SizedBox(height: 27),
                  _sectionTitle('备注', '留一点细节，方便以后查找'),
                  const SizedBox(height: 12),
                  _noteField(),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: _onPrimary,
                        disabledBackgroundColor: _primary.withValues(
                          alpha: 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _onPrimary,
                              ),
                            )
                          : Text(
                              widget.initial == null ? '保存账单' : '保存修改',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeSelector(bool isExpense) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.panel(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(child: _typeOption('支出', EntryType.expense, isExpense)),
          Expanded(child: _typeOption('收入', EntryType.income, !isExpense)),
        ],
      ),
    );
  }

  Widget _typeOption(String label, EntryType type, bool selected) {
    return InkWell(
      onTap: () => _changeType(type),
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _onPrimary : _muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _amountCard(bool isExpense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 19),
      decoration: BoxDecoration(
        color: AppColors.accentPanel(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isExpense
                      ? _accent
                      : _onPrimary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isExpense ? '支出金额' : '收入金额',
                style: TextStyle(
                  color: _onPrimary.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '¥',
                  style: TextStyle(
                    color: _onPrimary,
                    fontSize: 29,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  autofocus: widget.initial == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return RegExp(
                            r'^\d*(?:\.\d{0,2})?$',
                          ).hasMatch(newValue.text)
                          ? newValue
                          : oldValue;
                    }),
                  ],
                  onChanged: (_) {
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                  style: TextStyle(
                    color: _onPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                  cursorColor: _onPrimary,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: _onPrimary.withValues(alpha: 0.45),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _amountError ?? '人民币 · 精确到分，例如 28.50',
            style: TextStyle(
              color: _amountError == null
                  ? _onPrimary.withValues(alpha: 0.72)
                  : _onPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _primary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(_Category category, bool isExpense) {
    final selected = _category == category.name;
    return InkWell(
      onTap: () => setState(() => _category = category.name),
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isExpense ? _accent : _primary)
              : AppColors.panel(context),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? Colors.transparent : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: selected
                  ? (isExpense ? Colors.white : _onPrimary)
                  : _muted,
            ),
            const SizedBox(width: 7),
            Text(
              category.name,
              style: TextStyle(
                color: selected
                    ? (isExpense ? Colors.white : _onPrimary)
                    : _primary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePicker() {
    return Material(
      color: AppColors.panel(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 21,
                color: _accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_date.year} 年 ${_date.month.toString().padLeft(2, '0')} 月 '
                  '${_date.day.toString().padLeft(2, '0')} 日',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.panel(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _noteController,
        minLines: 2,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        style: TextStyle(color: _primary, fontSize: 15, height: 1.5),
        decoration: const InputDecoration(
          hintText: '例如：午餐、通勤、周末购物…',
          hintStyle: TextStyle(color: _muted, fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _Category {
  const _Category(this.name, this.icon);

  final String name;
  final IconData icon;
}
