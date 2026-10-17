/// Derived charge status. The status is never stored; it is computed from
/// allocations so it can never drift from the actual payments.
enum ChargeStatus { unpaid, partial, paid, waived }

ChargeStatus deriveChargeStatus({
  required int amountDue,
  required int paid,
  required bool waived,
}) {
  if (waived) return ChargeStatus.waived;
  if (paid >= amountDue) return ChargeStatus.paid;
  if (paid > 0) return ChargeStatus.partial;
  return ChargeStatus.unpaid;
}
