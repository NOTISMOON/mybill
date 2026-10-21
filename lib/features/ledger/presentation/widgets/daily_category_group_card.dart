import 'package:flutter/material.dart';

import '../../../../core/formatters/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ledger_entry.dart';
import 'entry_tile.dart';

/// A day's transactions with the same category and income/expense direction.
class DailyCategoryGroupCard extends StatefulWidget {
  const DailyCategoryGroupCard({
    super.key,
    required this.type,
    required this.category,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final EntryType type;
  final String category;
  final List<LedgerEntry> entries;
  final ValueChanged<LedgerEntry> onEdit;
  final ValueChanged<LedgerEntry> onDelete;

  @override
  State<DailyCategoryGroupCard> createState() => _DailyCategoryGroupCardState();
}

class _DailyCategoryGroupCardState extends State<DailyCategoryGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final income = widget.type == EntryType.income;
    final color = income ? AppColors.primary(context) : AppColors.coral;
    final total = widget.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.amountCents,
    );
    final amount = '${income ? '+' : '-'}${formatCny(total)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel(context),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 15, 12, 15),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        income
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${income ? '收入' : '支出'} · ${widget.entries.length} 笔',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 124),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          amount,
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.line),
            for (var index = 0; index < widget.entries.length; index++) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 66),
                  child: Divider(height: 1, color: AppColors.line),
                ),
              EntryTile(
                entry: widget.entries[index],
                onEdit: () => widget.onEdit(widget.entries[index]),
                onDelete: () => widget.onDelete(widget.entries[index]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
