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

  ChargeStatus get status =>
      deriveChargeStatus(amountDue: amountDue, paid: paid, waived: waived);

  int get remaining => math.max(0, amountDue - paid);

  bool isOverdue(DateTime asOf) =>
      !waived && paid < amountDue && dateOnly(dueDate).isBefore(dateOnly(asOf));
}

/// Aggregated numbers for the group dashboard.
class GroupSummary {
  const GroupSummary({
    required this.balance,
    required this.overdueTotal,
    this.overdueMemberCount = 0,
    this.currentPeriodLabel,
    this.currentPeriodPaidCount = 0,
    this.currentPeriodTotalCount = 0,
  });

  final int balance;
  final int overdueTotal;
  final int overdueMemberCount;
  final String? currentPeriodLabel;
  final int currentPeriodPaidCount;
  final int currentPeriodTotalCount;

  int get activityPct => currentPeriodTotalCount == 0
      ? 0
      : ((currentPeriodPaidCount / currentPeriodTotalCount) * 100).round();
}

/// Ringkas satu grup untuk layar pilih grup: jumlah anggota aktif + saldo kas.
class GroupPickerInfo {
  const GroupPickerInfo({required this.memberCount, required this.balance});

  final int memberCount;
  final int balance;
}

/// Information about a member who has overdue dues.
class MemberOverdueSummary {
  const MemberOverdueSummary({
    required this.memberId,
    required this.memberName,
    required this.unpaidPeriodsCount,
    required this.totalOverdueAmount,
    required this.oldestDueDate,
  });

  final String memberId;
  final String memberName;
  final int unpaidPeriodsCount;
  final int totalOverdueAmount;
  final DateTime oldestDueDate;
}

/// An allocation joined with the label of the period it pays into.
class AllocationDetail {
  const AllocationDetail({
    required this.id,
    required this.transactionId,
    required this.chargeId,
    required this.amountAllocated,
    required this.periodLabel,
  });

  final String id;
  final String transactionId;
  final String chargeId;
  final int amountAllocated;
  final String periodLabel;

  factory AllocationDetail.fromMap(Map<String, Object?> map) =>
      AllocationDetail(
        id: map['id'] as String,
        transactionId: map['transaction_id'] as String,
        chargeId: map['charge_id'] as String,
        amountAllocated: (map['amount_allocated'] as num).toInt(),
        periodLabel: map['period_label'] as String? ?? '',
      );
}
