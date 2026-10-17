import 'dart:math' as math;

import '../logic/dues_status.dart';
import '../utils/dates.dart';

/// A charge row joined with member info and its derived paid amount.
class PeriodMemberRow {
  const PeriodMemberRow({
    required this.chargeId,
    required this.memberId,
    required this.memberName,
    required this.amountDue,
    required this.paid,
    required this.waived,
    required this.dueDate,
  });

  final String chargeId;
  final String memberId;
  final String memberName;
  final int amountDue;
  final int paid;
  final bool waived;
  final DateTime dueDate;

  ChargeStatus get status => deriveChargeStatus(
        amountDue: amountDue,
        paid: paid,
        waived: waived,
      );

  int get remaining => math.max(0, amountDue - paid);

  bool isOverdue(DateTime asOf) =>
      !waived &&
      paid < amountDue &&
      dateOnly(dueDate).isBefore(dateOnly(asOf));
}

/// Aggregated numbers for the group dashboard.
class GroupSummary {
  const GroupSummary({
    required this.balance,
    required this.overdueTotal,
    this.currentPeriodLabel,
    this.currentPeriodPaidCount = 0,
    this.currentPeriodTotalCount = 0,
  });

  final int balance;
  final int overdueTotal;
  final String? currentPeriodLabel;
  final int currentPeriodPaidCount;
  final int currentPeriodTotalCount;

  int get activityPct => currentPeriodTotalCount == 0
      ? 0
      : ((currentPeriodPaidCount / currentPeriodTotalCount) * 100).round();
}
