import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/ledger/data/ledger_store.dart';
import '../features/ledger/domain/ledger_entry.dart';
import '../features/ledger/presentation/ledger_page.dart';
import '../features/profile/data/appearance_store.dart';
import '../features/profile/domain/appearance_module.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/statistics/presentation/statistics_page.dart';
import 'app_router.dart';
import 'widgets/capsule_navigation_bar.dart';

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.appearance});

  final AppearanceStore appearance;

  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  final LedgerStore store = LedgerStore();
  late Future<void> loading;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int tab = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
    loading = store.load();
  }

  @override
  void dispose() {
    store.removeListener(refresh);
    store.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void openEditor([LedgerEntry? entry]) {
    Navigator.of(context).pushNamed(
      AppRoutes.entryEditor,
      arguments: EntryEditorRouteArguments(
        initial: entry,
        onSave: store.upsert,
        appearance: widget.appearance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.coral,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '账本读取失败',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(() => loading = store.load()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: tab,
            children: [
              Theme(
                data: _moduleTheme(AppearanceModule.ledger),
                child: LedgerPage(
                  entries: store.entries,
                  month: month,
                  onMonthChanged: (value) => setState(() => month = value),
                  onAdd: () => openEditor(),
                  onEdit: openEditor,
                  onDelete: (entry) async {
                    await store.remove(entry.id);
                  },
                ),
              ),
              Theme(
                data: _moduleTheme(AppearanceModule.statistics),
                child: StatisticsPage(
                  entries: store.entries,
                  month: month,
                  onMonthChanged: (value) => setState(() => month = value),
                  onOpenMonth: (value) => setState(() {
                    month = value;
                    tab = 0;
                  }),
                ),
              ),
              Theme(
                data: _moduleTheme(AppearanceModule.profile),
                child: ProfilePage(store: store, appearance: widget.appearance),
              ),
            ],
          ),
        ),
        floatingActionButton: tab == 2
            ? null
            : FloatingActionButton.extended(
                onPressed: () => openEditor(),
                backgroundColor: AppColors.primary(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                icon: const Icon(Icons.add_rounded),
                label: const Text('记一笔'),
              ),
        bottomNavigationBar: Theme(
          data: _moduleTheme(AppearanceModule.navigation),
          child: CapsuleNavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
          ),
        ),
      );
    },
  );

  ThemeData _moduleTheme(AppearanceModule module) {
    final settings = widget.appearance.module(module);
    return AppTheme.light(
      settings.color,
      hasBackground: widget.appearance.backgroundBytes != null,
      panelOpacity: settings.panelOpacity,
    );
  }
}
