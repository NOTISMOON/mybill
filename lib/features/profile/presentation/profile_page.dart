import 'package:flutter/material.dart';

import '../../../core/formatters/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/app_router.dart';
import '../../ledger/data/ledger_store.dart';
import '../../ledger/presentation/widgets/principal_editor_dialog.dart';
import '../data/appearance_store.dart';
import '../data/backup_service.dart';

enum _ImportMode { merge, replace }

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store, required this.appearance});

  final LedgerStore store;
  final AppearanceStore appearance;
  static const _backup = BackupService();

  Future<void> _editPrincipal(BuildContext context) async {
    await showPrincipalEditorDialog(
      context,
      principalCents: store.principalCents,
      onSave: store.setPrincipalCents,
    );
  }

  void _message(BuildContext context, String value) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _export(BuildContext context) async {
    try {
      final destination = await _backup.saveJson(store.getExportJson());
      if (destination != null && context.mounted) {
        _message(context, '已保存 JSON 备份到手机本地');
      }
    } catch (error) {
      if (context.mounted) _message(context, '导出失败：$error');
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final size = MediaQuery.sizeOf(context);
      await _backup.shareJson(
        store.getExportJson(),
        Rect.fromLTWH(size.width / 2, size.height / 2, 2, 2),
      );
    } catch (error) {
      if (context.mounted) _message(context, '分享失败：$error');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final source = await _backup.pickJson();
      if (source == null) return;
      final preview = store.previewImport(source);
      if (!context.mounted) return;
      final mode = await showDialog<_ImportMode>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('导入 JSON 账本'),
          content: Text(
            '文件中有 ${preview.totalEntries} 笔记录，其中 ${preview.newEntries} 笔是新记录，'
            '${preview.duplicateEntries} 笔 ID 已存在。\n\n'
            '文件中的期初本金：${formatCny(preview.principalCents)}。\n\n'
            '合并会按 ID 更新重复记录，并保留当前本金；替换会先备份当前账本，'
            '再用文件中的记录和本金覆盖。旧版备份的本金按 ¥0.00 处理。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ImportMode.replace),
              child: const Text('替换'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, _ImportMode.merge),
              child: const Text('合并'),
            ),
          ],
        ),
      );
      if (mode == null) return;
      if (mode == _ImportMode.replace) {
        await _backup.savePreImportBackup(store.getExportJson());
      }
      await store.importJson(source, replace: mode == _ImportMode.replace);
      if (context.mounted) _message(context, '已导入 ${preview.totalEntries} 笔记录');
    } on FormatException catch (error) {
      if (context.mounted) _message(context, 'JSON 格式不正确：${error.message}');
    } catch (error) {
      if (context.mounted) _message(context, '导入失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Text(
            '我的',
            style: TextStyle(
              color: AppColors.accentPanel(context),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '你的账本，只在你的设备上',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary(context),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本地账本',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '已有 ${store.entries.length} 笔记录 · ledger.json',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '资金',
            style: TextStyle(
              color: AppColors.primary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _ActionTile(
              icon: Icons.account_balance_wallet_outlined,
              title: '设置本金',
              subtitle: '期初本金 ${formatCny(store.principalCents)}',
              onTap: () => _editPrincipal(context),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '偏好',
            style: TextStyle(
              color: AppColors.primary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _ActionTile(
              icon: Icons.palette_outlined,
              title: '外观偏好',
              subtitle: '壁纸、自动配色与各模块透明度',
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.appearancePreferences,
                arguments: appearance,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '数据备份',
            style: TextStyle(
              color: AppColors.primary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.save_alt_rounded,
                  title: '导出到手机',
                  subtitle: '选择位置保存 JSON 备份文件',
                  onTap: () => _export(context),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 70),
                  child: Divider(height: 1, color: AppColors.line),
                ),
                _ActionTile(
                  icon: Icons.ios_share_rounded,
                  title: '分享备份',
                  subtitle: '通过其他应用发送 JSON 文件',
                  onTap: () => _share(context),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 70),
                  child: Divider(height: 1, color: AppColors.line),
                ),
                _ActionTile(
                  icon: Icons.file_download_outlined,
                  title: '导入 JSON',
                  subtitle: '从备份文件合并或替换记录',
                  onTap: () => _import(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '首次启动会自动创建本地账本文件。建议定期导出到手机文件夹；卸载应用或更换设备时，可用备份恢复记录。',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '关于',
            style: TextStyle(
              color: AppColors.primary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.panel(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const _InfoRow('货币', '人民币 CNY'),
                const SizedBox(height: 13),
                const _InfoRow('金额精度', '分（整数）'),
                const SizedBox(height: 13),
                _InfoRow('账本版本', '${LedgerStore.schemaVersion}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary(context), size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
