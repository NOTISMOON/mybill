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

  test(
    'first load creates an empty file and later loads preserve it',
    () async {
      final file = File('${directory.path}/ledger.json');
      expect(await file.exists(), isFalse);

      final store = LedgerStore(directory: directory);
      await store.load();
      expect(await file.exists(), isTrue);
      expect(store.entries, isEmpty);
      expect(jsonDecode(await file.readAsString()), {
        'schemaVersion': 1,
        'entries': <Object>[],
      });

      await store.upsert(
        LedgerEntry(
          id: 'existing',
          type: EntryType.expense,
          amountCents: 300,
          category: '交通',
          date: DateTime(2026, 10, 20),
          note: '',
        ),
      );
      final savedJson = await file.readAsString();
      final restored = LedgerStore(directory: directory);
      await restored.load();
      expect(restored.entries.single.id, 'existing');
      expect(await file.readAsString(), savedJson);
      store.dispose();
      restored.dispose();
    },
  );

  test('stores integer fen and reloads the JSON ledger', () async {
    final store = LedgerStore(directory: directory);
    await store.load();
    await store.upsert(
      LedgerEntry(
        id: 'expense-1',
        type: EntryType.expense,
        amountCents: 1250,
        category: '餐饮',
        date: DateTime(2026, 10, 20),
        note: '午餐',
      ),
    );

    final saved =
        jsonDecode(await File('${directory.path}/ledger.json').readAsString())
            as Map<String, dynamic>;
    expect(saved['schemaVersion'], 1);
    expect((saved['entries'] as List).single['amountCents'], 1250);

    final restored = LedgerStore(directory: directory);
    await restored.load();
    expect(restored.entries.single.note, '午餐');
    expect(restored.entries.single.date, DateTime(2026, 10, 20));
    store.dispose();
    restored.dispose();
  });

  test(
    'import previews and merges by ID, and rejects unsupported versions',
    () async {
      final store = LedgerStore(directory: directory);
      await store.load();
      await store.upsert(
        LedgerEntry(
          id: 'same',
          type: EntryType.expense,
          amountCents: 500,
          category: '交通',
          date: DateTime(2026, 10, 1),
          note: '',
        ),
      );
      const imported = '''{
      "schemaVersion": 1,
      "entries": [
        {"id":"same","type":"expense","amountCents":600,"category":"交通","date":"2026-10-01","note":"更新"},
        {"id":"new","type":"income","amountCents":10000,"category":"工资","date":"2026-10-02","note":""}
      ]
    }''';
      final preview = store.previewImport(imported);
      expect(preview.totalEntries, 2);
      expect(preview.newEntries, 1);
      expect(preview.duplicateEntries, 1);

      await store.importJson(imported, replace: false);
      expect(store.entries.length, 2);
      expect(
        store.entries.firstWhere((entry) => entry.id == 'same').amountCents,
        600,
      );
      expect(
        () => store.previewImport('{"schemaVersion": 2, "entries": []}'),
        throwsFormatException,
      );
      store.dispose();
    },
  );
}
