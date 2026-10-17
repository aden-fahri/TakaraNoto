import 'dart:math' as math;

/// One unpaid charge ready to receive an allocation.
class DebtItem {
  const DebtItem({
    required this.chargeId,
    required this.remainingDue,
    required this.dueDate,
  });

  final String chargeId;
  final int remainingDue;
  final DateTime dueDate;
}

/// A planned allocation of [amount] rupiah to [chargeId].
class AllocationDraft {
  const AllocationDraft({required this.chargeId, required this.amount});

  final String chargeId;
  final int amount;
}

/// Result of a FIFO allocation pass.
class AllocationResult {
  const AllocationResult({required this.allocations, required this.leftover});

  final List<AllocationDraft> allocations;
  final int leftover;

  int get allocatedTotal =>
      allocations.fold(0, (sum, draft) => sum + draft.amount);
}

/// Pure FIFO allocator: fills the oldest due charges first.
///
/// The leftover (money that could not be allocated to any existing charge)
/// must be persisted as a member credit by the caller, never dropped.
AllocationResult allocateFifo({
  required int amount,
  required List<DebtItem> debts,
}) {
  if (amount <= 0) {
    return const AllocationResult(allocations: [], leftover: 0);
  }

  final sorted = [...debts]..sort((a, b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      if (byDate != 0) return byDate;
      return a.chargeId.compareTo(b.chargeId);
    });

  final allocations = <AllocationDraft>[];
  var remaining = amount;
  for (final debt in sorted) {
    if (remaining <= 0) break;
    if (debt.remainingDue <= 0) continue;
    final take = math.min(remaining, debt.remainingDue);
    allocations.add(AllocationDraft(chargeId: debt.chargeId, amount: take));
    remaining -= take;
  }

  return AllocationResult(allocations: allocations, leftover: remaining);
}
