import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the editor for the opening balance used by every ledger entry.
///
/// Returns `true` after [onSave] succeeds, or `null` when dismissed.
Future<bool?> showPrincipalEditorDialog(
  BuildContext context, {
  required int principalCents,
  required Future<void> Function(int cents) onSave,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _PrincipalEditorDialog(principalCents: principalCents, onSave: onSave),
);

class _PrincipalEditorDialog extends StatefulWidget {
  const _PrincipalEditorDialog({
    required this.principalCents,
    required this.onSave,
  });

  final int principalCents;
  final Future<void> Function(int cents) onSave;

  @override
  State<_PrincipalEditorDialog> createState() => _PrincipalEditorDialogState();
}

class _PrincipalEditorDialogState extends State<_PrincipalEditorDialog> {
  late final TextEditingController _amountController;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final whole = widget.principalCents ~/ 100;
    final fraction = (widget.principalCents % 100).toString().padLeft(2, '0');
    _amountController = TextEditingController(text: '$whole.$fraction');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static int? _parseCents(String input) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
    if (match == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return int.tryParse('${match.group(1)}$fraction');
  }

  Future<void> _save() async {
    if (_saving) return;
    final cents = _parseCents(_amountController.text);
    if (cents == null) {
      setState(() => _error = '请输入不小于 0 的金额，最多保留两位小数');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSave(cents);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('设置本金'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本金是所有账单发生前的起始金额。总资产按“本金 + 全部收入 - 全部支出”计算；调整本金不会修改已有账单。',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            autofocus: true,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: '本金（人民币）',
              prefixText: '¥ ',
              hintText: '例如 10000.00',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    ),
  );
}
