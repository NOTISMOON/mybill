import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/ledger_entry.dart';

/// Persists the ledger as Documents/ledger.json.
class LedgerStore extends ChangeNotifier {
  LedgerStore({this.directory});

  static const int schemaVersion = 1;

  final Directory? directory;
  List<LedgerEntry> _entries = const [];
  Future<void> _pending = Future<void>.value();
  bool _loaded = false;

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(_entries);

  /// Reads disk data, creating an empty ledger file on first use.
  Future<void> load() => _serially(_loadFromDisk);

  /// Inserts or replaces an entry with the same id, then saves it to disk.
  Future<void> upsert(LedgerEntry entry) => _serially(() async {
    await _ensureLoaded();
    final next = [..._entries];
    final index = next.indexWhere((existing) => existing.id == entry.id);
    if (index == -1) {
      next.add(entry);
    } else {
      next[index] = entry;
    }
    await _save(next);
  });

  /// Removes an entry by id. Returns whether an entry was removed.
  Future<bool> remove(String id) => _serially(() async {
    await _ensureLoaded();
    final next = _entries.where((entry) => entry.id != id).toList();
    if (next.length == _entries.length) return false;
    await _save(next);
    return true;
  });

  /// Validates an import and reports how many ids are already present.
  /// Call [load] first to compare with the file on disk.
  ImportPreview previewImport(String json) {
    final incoming = _decode(json);
    final existingIds = _entries.map((entry) => entry.id).toSet();
    final duplicateCount = incoming
        .where((entry) => existingIds.contains(entry.id))
        .length;
    return ImportPreview(
      totalEntries: incoming.length,
      newEntries: incoming.length - duplicateCount,
      duplicateEntries: duplicateCount,
    );
  }

  /// Replaces all entries, or merges by id with imported entries taking priority.
  Future<ImportPreview> importJson(String json, {required bool replace}) {
    final incoming = _decode(json);
    return _serially(() async {
      await _ensureLoaded();
      final existingIds = _entries.map((entry) => entry.id).toSet();
      final duplicateCount = incoming
          .where((entry) => existingIds.contains(entry.id))
          .length;
      final preview = ImportPreview(
        totalEntries: incoming.length,
        newEntries: incoming.length - duplicateCount,
        duplicateEntries: duplicateCount,
      );
      final next = replace ? [...incoming] : [..._entries];
      if (!replace) {
        for (final entry in incoming) {
          final index = next.indexWhere((existing) => existing.id == entry.id);
          if (index == -1) {
            next.add(entry);
          } else {
            next[index] = entry;
          }
        }
      }
      await _save(next);
      return preview;
    });
  }

  /// Exports the currently loaded entries as a portable, readable JSON string.
  String getExportJson() => _encode(_entries);

  Future<void> _ensureLoaded() async {
    if (!_loaded) await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final file = await _ledgerFile();
    if (!await file.exists()) {
      await _save(<LedgerEntry>[]);
      return;
    }
    final next = _decode(await file.readAsString());
    _entries = List<LedgerEntry>.unmodifiable(next);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save(List<LedgerEntry> next) async {
    final file = await _ledgerFile();
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(_encode(next), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    _entries = List<LedgerEntry>.unmodifiable(next);
    _loaded = true;
    notifyListeners();
  }

  Future<File> _ledgerFile() async {
    final documentsDirectory =
        directory ?? await getApplicationDocumentsDirectory();
    return File(
      '${documentsDirectory.path}${Platform.pathSeparator}ledger.json',
    );
  }

  Future<T> _serially<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String _encode(List<LedgerEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': schemaVersion,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      });

  static List<LedgerEntry> _decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid ledger JSON: ${error.message}');
    }
    final data = _requireObject(decoded, 'ledger');
    _requireKeys(data, const {'schemaVersion', 'entries'}, 'ledger');
    if (data['schemaVersion'] is! int ||
        data['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported ledger schemaVersion.');
    }
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Ledger entries must be a list.');
    }
    final entries = rawEntries
        .map((value) => LedgerEntry.fromJson(value))
        .toList();
    final ids = <String>{};
    for (final entry in entries) {
      if (!ids.add(entry.id)) {
        throw FormatException('Duplicate entry id: ${entry.id}');
      }
    }
    return entries;
  }
}

Map<String, dynamic> _requireObject(Object? value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$name must be a JSON object.');
  }
  return value;
}

void _requireKeys(
  Map<String, dynamic> data,
  Set<String> expectedKeys,
  String name,
) {
  if (data.length != expectedKeys.length ||
      !data.keys.toSet().containsAll(expectedKeys)) {
    throw FormatException('$name has missing or unknown fields.');
  }
}
