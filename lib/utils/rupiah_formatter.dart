import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats text input automatically as Indonesian Rupiah with dot thousands separators (e.g. 25.000, 1.500.000).
class RupiahInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Strip non-digits
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(cleanText) ?? 0;
    final newString = _formatter.format(number);

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  /// Helper to format a number into dot-separated thousands (e.g. 25000 -> "25.000").
  static String format(num value) {
    return NumberFormat.decimalPattern('id').format(value);
  }

  /// Helper to parse a formatted string like "25.000" into an integer 25000.
  static int parseClean(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }
}

