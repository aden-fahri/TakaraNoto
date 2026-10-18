import 'package:intl/intl.dart';

import '../models/entities.dart';

/// Formatting helpers for ZainNoto amounts and dates.
String formatRupiah(int amount) => NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

/// Formats [date] with [pattern]; falls back to the raw value when the date
/// is unparsable or Indonesian locale data is unavailable, so a missing
/// `initializeDateFormatting` can never crash a screen build.
String _formatDateId(String date, String pattern) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  try {
    return DateFormat(pattern, 'id').format(parsed);
  } catch (_) {
    return date;
  }
}

/// Compact label for matrix columns: `Okt 24` (monthly) or `12 Okt` (weekly).
String periodShortLabel(Period period) {
  final start = DateTime.tryParse(period.startDate);
  if (start == null) return period.label;
  if (period.label.startsWith('Minggu')) {
    return _formatDateId(period.startDate, 'd MMM');
  }
  return _formatDateId(period.startDate, 'MMM yy');
}

/// `2024-10-16` → `16 Okt 2024`.
String formatTanggalSingkat(String date) => _formatDateId(date, 'd MMM yyyy');

/// `2024-10-16` → `16 Oktober 2024`.
String formatTanggal(String date) => _formatDateId(date, 'd MMMM yyyy');

/// Timestamp ISO → `16 Okt 2024 14:05` (untuk riwayat audit).
String formatWaktuLengkap(String iso) => _formatDateId(iso, 'd MMM yyyy HH:mm');
