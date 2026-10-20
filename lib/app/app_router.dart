import 'package:flutter/material.dart';

import '../features/ledger/domain/ledger_entry.dart';
import '../features/ledger/presentation/entry_editor_page.dart';
import '../features/profile/data/appearance_store.dart';
import '../features/profile/domain/appearance_module.dart';
import '../features/profile/presentation/appearance_preferences_page.dart';
import '../core/theme/app_theme.dart';

abstract final class AppRoutes {
  static const entryEditor = '/entry-editor';
  static const appearancePreferences = '/appearance-preferences';
}

class EntryEditorRouteArguments {
  const EntryEditorRouteArguments({
    required this.onSave,
    required this.appearance,
    this.initial,
  });

  final LedgerEntry? initial;
  final Future<void> Function(LedgerEntry) onSave;
  final AppearanceStore appearance;
}

abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.appearancePreferences) {
      final appearance = settings.arguments;
      if (appearance is! AppearanceStore) {
        throw ArgumentError('Appearance route requires AppearanceStore.');
      }
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AnimatedBuilder(
          animation: appearance,
          builder: (context, _) => Theme(
            data: AppTheme.light(
              appearance.module(AppearanceModule.profile).color,
              hasBackground: appearance.backgroundBytes != null,
              panelOpacity: appearance
                  .module(AppearanceModule.profile)
                  .panelOpacity,
            ),
            child: AppearancePreferencesPage(appearance: appearance),
          ),
        ),
      );
    }
    if (settings.name != AppRoutes.entryEditor) return null;
    final args = settings.arguments;
    if (args is! EntryEditorRouteArguments) {
      throw ArgumentError(
        'Entry editor route requires EntryEditorRouteArguments.',
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) {
        final editor = args.appearance.module(AppearanceModule.editor);
        return Theme(
          data: AppTheme.light(
            editor.color,
            hasBackground: args.appearance.backgroundBytes != null,
            panelOpacity: editor.panelOpacity,
          ),
          child: EntryEditorPage(initial: args.initial, onSave: args.onSave),
        );
      },
    );
  }
}
