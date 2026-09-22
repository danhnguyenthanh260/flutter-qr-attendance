String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

bool isDateKeyWithin(String value, DateTime from, DateTime to) {
  final date = parseDateKey(value);
  if (date == null) return false;
  final lower = startOfDay(from);
  final upper = startOfDay(to);
  return !date.isBefore(lower) && !date.isAfter(upper);
}
