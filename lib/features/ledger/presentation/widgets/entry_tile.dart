import 'package:flutter/material.dart';

import '../../../../core/formatters/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ledger_entry.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final LedgerEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    final color = income ? AppColors.primary(context) : AppColors.coral;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: income
                      ? color.withValues(alpha: 0.12)
                      : const Color(0xFFFCEBE5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(entry.category, income),
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
                      entry.category,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${income ? '+' : '-'}${formatCny(entry.amountCents)}',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.muted,
                  size: 19,
                ),
                onSelected: (action) =>
                    action == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category, bool income) {
  if (income) {
    if (category.contains('工资')) return Icons.payments_outlined;
    if (category.contains('奖金')) return Icons.card_giftcard_outlined;
    return Icons.savings_outlined;
  }
  if (category.contains('餐')) return Icons.restaurant_outlined;
  if (category.contains('交通')) return Icons.directions_bus_outlined;
  if (category.contains('购物')) return Icons.shopping_bag_outlined;
  if (category.contains('住') || category.contains('家')) {
    return Icons.home_outlined;
  }
  if (category.contains('娱乐')) return Icons.sports_esports_outlined;
  if (category.contains('医疗')) return Icons.medical_services_outlined;
  if (category.contains('学习')) return Icons.menu_book_outlined;
  return Icons.more_horiz_rounded;
}
