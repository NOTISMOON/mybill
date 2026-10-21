import 'package:flutter/material.dart';

import '../../../../core/formatters/currency.dart';
import '../../../../core/theme/app_theme.dart';

/// A balance for the whole ledger, independent of the selected month or year.
class TotalAssetsCard extends StatelessWidget {
  const TotalAssetsCard({
    super.key,
    required this.totalAssetsCents,
    required this.principalCents,
    required this.netCashFlowCents,
    required this.onEditPrincipal,
  });

  final int totalAssetsCents;
  final int principalCents;
  final int netCashFlowCents;
  final VoidCallback onEditPrincipal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final panel = AppColors.accentPanel(context);
    final foreground = colors.onPrimary;
    final shadowColor = foreground.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    final textShadow = panel.a < 0.45
        ? [Shadow(color: shadowColor, blurRadius: 5)]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.primary.withValues(alpha: panel.a < 0.45 ? 0.35 : 0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '总资产',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: textShadow,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEditPrincipal,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('设置本金'),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCny(totalAssetsCents),
                style: TextStyle(
                  color: foreground,
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  shadows: textShadow,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: foreground.withValues(alpha: 0.28)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceMetric(
                  label: '期初本金',
                  amount: formatCny(principalCents),
                  color: foreground,
                  shadows: textShadow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceMetric(
                  label: '累计净收支',
                  amount: netCashFlowCents > 0
                      ? '+${formatCny(netCashFlowCents)}'
                      : formatCny(netCashFlowCents),
                  color: foreground,
                  shadows: textShadow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.shadows,
  });

  final String label;
  final String amount;
  final Color color;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          shadows: shadows,
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              shadows: shadows,
            ),
          ),
        ),
      ),
    ],
  );
}
