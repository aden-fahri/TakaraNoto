import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/logic/dues_status.dart';

/// Shared colors and labels for derived dues statuses across the Iuran UI.
Color duesStatusColor(
  AppTokens t,
  ChargeStatus status, {
  bool overdue = false,
}) {
  switch (status) {
    case ChargeStatus.paid:
      return t.income;
    case ChargeStatus.partial:
      return Color.lerp(t.warning, t.textPrimary, 0.35)!;
    case ChargeStatus.unpaid:
      return overdue ? t.expense : t.textMuted;
    case ChargeStatus.waived:
      return t.textMuted;
  }
}

String duesStatusLabel(ChargeStatus status) {
  switch (status) {
    case ChargeStatus.paid:
      return 'Lunas';
    case ChargeStatus.partial:
      return 'Sebagian';
    case ChargeStatus.unpaid:
      return 'Belum Bayar';
    case ChargeStatus.waived:
      return 'Bebas';
  }
}
