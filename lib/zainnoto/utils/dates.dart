/// Date helpers for ZainNoto.
///
/// All persisted dates use the `YYYY-MM-DD` format (no timezone), while
/// timestamps use ISO-8601 UTC strings.
const List<String> monthNamesId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String dateToStr(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime dateFromStr(String value) => DateTime.parse(value);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String nowIso() => DateTime.now().toUtc().toIso8601String();
