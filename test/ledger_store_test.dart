import 'dart:convert';
import 'dart:io';

import 'package:bill/features/ledger/data/ledger_store.dart';
import 'package:bill/features/ledger/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bill-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('creates a version 2 ledger with zero principal', () async {
    final file = File('${directory.path}/ledger.json');
    expect(await file.exists(), isFalse);

    final store = LedgerStore(directory: directory);
    await store.load();
    expect(store.entries, isEmpty);
    expect(store.principalCents, 0);
    expect(store.totalAssetsCents, 0);
    expect(jsonDecode(await file.readAsString()), {
      'schemaVersion': 2,
      'principalCents': 0,
      'entries': <Object>[],
    });
    store.dispose();
  });

  test('principal and all-time income and expense determine assets', () async {
    final store = LedgerStore(directory: directory);
    await store.load();
    await store.setPrincipalCents(100000);
    await store.upsert(_entry('older-income', EntryType.income, 25050, 2025));
    await store.upsert(_entry('expense', EntryType.expense, 1250, 2026));
    expect(store.totalAssetsCents, 123800);

    // Editing and deleting a transaction must change the derived assets.
    await store.upsert(_entry('expense', EntryType.expense, 2500, 2026));
    expect(store.totalAssetsCents, 122550);
    expect(await store.remove('older-income'), isTrue);
    expect(store.totalAssetsCents, 97500);
    expect(await store.remove('missing'), isFalse);

    final file = File('${directory.path}/ledger.json');
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(saved['schemaVersion'], 2);
    expect(saved['principalCents'], 100000);
    expect((saved['entries'] as List).single['amountCents'], 2500);

    final restored = LedgerStore(directory: directory);
    await restored.load();
    expect(restored.principalCents, 100000);
    expect(restored.totalAssetsCents, 97500);
    expect(restored.entries.single.date, DateTime(2026, 10, 20));
    expect(await file.readAsString(), store.getExportJson());
    store.dispose();
    restored.dispose();
  });

  test(
    'loads and migrates an existing version 1 ledger without losing entries',
    () async {
      final file = File('${directory.path}/ledger.json');
      await file.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'entries': [
            _entry('old-income', EntryType.income, 54321, 2025).toJson(),
          ],
        }),
      );

      final store = LedgerStore(directory: directory);
      await store.load();
      expect(store.principalCents, 0);
      expect(store.totalAssetsCents, 54321);
      expect(store.entries.single.id, 'old-income');
      expect(jsonDecode(await file.readAsString()), {
        'schemaVersion': 2,
        'principalCents': 0,
        'entries': [
          _entry('old-income', EntryType.income, 54321, 2025).toJson(),
        ],
      });
      store.dispose();
    },
  );

  test(
    'merge keeps local principal; replace adopts backup principal',
    () async {
      final store = LedgerStore(directory: directory);
      await store.load();
      await store.setPrincipalCents(50000);
      await store.upsert(_entry('same', EntryType.expense, 500, 2026));
      final incoming = jsonEncode({
        'schemaVersion': 2,
        'principalCents': 80000,
        'entries': [
          _entry('same', EntryType.expense, 600, 2026).toJson(),
          _entry('new', EntryType.income, 10000, 2025).toJson(),
        ],
      });

      final preview = store.previewImport(incoming);
      expect(preview.totalEntries, 2);
      expect(preview.newEntries, 1);
      expect(preview.duplicateEntries, 1);
      expect(preview.principalCents, 80000);

      await store.importJson(incoming, replace: false);
      expect(store.entries.length, 2);
      expect(store.principalCents, 50000);
      expect(store.totalAssetsCents, 59400);
      expect(
        store.entries.firstWhere((entry) => entry.id == 'same').amountCents,
        600,
      );

      final mergedBackup =
          jsonDecode(store.getExportJson()) as Map<String, dynamic>;
      expect(mergedBackup['principalCents'], 50000);
      await store.importJson(incoming, replace: true);
      expect(store.principalCents, 80000);
      expect(store.totalAssetsCents, 89400);
      expect(
        (jsonDecode(store.getExportJson()) as Map)['principalCents'],
        80000,
      );

      // Older backups have no principal: replacing with one resets it to zero.
      final oldBackup = jsonEncode({
        'schemaVersion': 1,
        'entries': [_entry('old', EntryType.expense, 100, 2024).toJson()],
      });
      expect(store.previewImport(oldBackup).principalCents, 0);
      await store.importJson(oldBackup, replace: true);
      expect(store.principalCents, 0);
      expect(store.totalAssetsCents, -100);
      expect(store.entries.single.id, 'old');
      store.dispose();
    },
  );

  test('rejects invalid principal and unsupported backup versions', () async {
    final store = LedgerStore(directory: directory);
    await store.load();
    expect(() => store.setPrincipalCents(-1), throwsArgumentError);
    expect(store.principalCents, 0);
    expect(
      () => store.previewImport(
        '{"schemaVersion":2,"principalCents":-1,"entries":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => store.previewImport(
        '{"schemaVersion":2,"principalCents":1.5,"entries":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => store.previewImport('{"schemaVersion":3,"entries":[]}'),
      throwsFormatException,
    );
    store.dispose();
  });
}

LedgerEntry _entry(String id, EntryType type, int cents, int year) =>
    LedgerEntry(
      id: id,
      type: type,
      amountCents: cents,
      category: type == EntryType.income ? '工资' : '交通',
      date: DateTime(year, 10, 20),
      note: '',
    );
