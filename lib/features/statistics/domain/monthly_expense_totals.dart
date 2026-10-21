import '../../ledger/domain/ledger_entry.dart';

/// Expense totals in cents for every calendar day of [month], including zero days.
List<int> monthlyExpenseTotals(DateTime month, Iterable<LedgerEntry> entries) {
  final totals = List<int>.filled(
    DateTime(month.year, month.month + 1, 0).day,
    0,
  );
  for (final entry in entries) {
    if (entry.type == EntryType.expense &&
        entry.date.year == month.year &&
        entry.date.month == month.month) {
      totals[entry.date.day - 1] += entry.amountCents;
    }
  }
  return totals;
}
