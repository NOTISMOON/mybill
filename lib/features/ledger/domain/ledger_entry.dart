import 'package:flutter/foundation.dart';

enum EntryType { income, expense }

/// A single transaction. Money is stored in cents to avoid rounding errors.
@immutable
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.category,
    required this.date,
    required this.note,
  }) {
    if (id.trim().isEmpty) {
      throw const FormatException('Entry id must not be empty.');
    }
    if (amountCents <= 0) {
      throw const FormatException('Entry amountCents must be positive.');
    }
    if (category.trim().isEmpty) {
      throw const FormatException('Entry category must not be empty.');
    }
    if (date.year < 1 || date.year > 9999) {
      throw const FormatException('Entry date year is out of range.');
    }
  }

  final String id;
  final EntryType type;
  final int amountCents;
  final String category;
  final DateTime date;
  final String note;

  factory LedgerEntry.fromJson(Object? value) {
    final data = _requireObject(value, 'entry');
    _requireKeys(data, const {
      'id',
      'type',
      'amountCents',
      'category',
      'date',
      'note',
    }, 'entry');

    final id = _requireString(data['id'], 'entry.id');
    final typeValue = _requireString(data['type'], 'entry.type');
    final type = switch (typeValue) {
      'income' => EntryType.income,
      'expense' => EntryType.expense,
      _ => throw const FormatException('Entry type must be income or expense.'),
    };
    final amount = data['amountCents'];
    if (amount is! int || amount <= 0) {
      throw const FormatException(
        'Entry amountCents must be a positive integer.',
      );
    }
    final category = _requireString(data['category'], 'entry.category');
    final date = _parseDate(_requireString(data['date'], 'entry.date'));
    final note = _requireString(data['note'], 'entry.note');

    return LedgerEntry(
      id: id,
      type: type,
      amountCents: amount,
      category: category,
      date: date,
      note: note,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'type': type.name,
    'amountCents': amountCents,
    'category': category,
    'date': _formatDate(date),
    'note': note,
  };
}

/// Counts for an import compared with the currently loaded ledger.
@immutable
class ImportPreview {
  const ImportPreview({
    required this.totalEntries,
    required this.newEntries,
    required this.duplicateEntries,
  });

  final int totalEntries;
  final int newEntries;
  final int duplicateEntries;
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

String _requireString(Object? value, String name) {
  if (value is! String) throw FormatException('$name must be a string.');
  return value;
}

DateTime _parseDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Entry date must use YYYY-MM-DD.');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    throw const FormatException('Entry date is invalid.');
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('Entry date is invalid.');
  }
  return date;
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
