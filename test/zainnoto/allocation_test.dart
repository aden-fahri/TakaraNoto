import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/allocation.dart';

void main() {
  DebtItem debt(String id, int remaining, DateTime due) => DebtItem(
        chargeId: id,
        remainingDue: remaining,
        dueDate: due,
      );

  test('mengisi tagihan paling tua lebih dulu (FIFO)', () {
    final result = allocateFifo(
      amount: 30000,
      debts: [
        debt('B', 20000, DateTime(2026, 1, 17)),
        debt('A', 20000, DateTime(2026, 1, 10)),
      ],
    );

    expect(result.allocations.map((a) => a.chargeId).toList(), ['A', 'B']);
    expect(result.allocations[0].amount, 20000);
    expect(result.allocations[1].amount, 10000);
    expect(result.leftover, 0);
  });

  test('sisa yang tidak teralokasi dikembalikan sebagai leftover', () {
    final result = allocateFifo(
      amount: 50000,
      debts: [
        debt('A', 20000, DateTime(2026, 1, 10)),
        debt('B', 20000, DateTime(2026, 1, 17)),
      ],
    );

    expect(result.allocatedTotal, 40000);
    expect(result.leftover, 10000);
  });

  test('melewati tagihan yang sudah lunas', () {
    final result = allocateFifo(
      amount: 10000,
      debts: [
        debt('A', 0, DateTime(2026, 1, 10)),
        debt('B', 20000, DateTime(2026, 1, 17)),
      ],
    );

    expect(result.allocations.single.chargeId, 'B');
  });

  test('nominal nol atau negatif tidak menghasilkan alokasi', () {
    final zero = allocateFifo(
      amount: 0,
      debts: [debt('A', 20000, DateTime(2026, 1, 10))],
    );
    final negative = allocateFifo(
      amount: -100,
      debts: [debt('A', 20000, DateTime(2026, 1, 10))],
    );

    expect(zero.allocations, isEmpty);
    expect(zero.leftover, 0);
    expect(negative.allocations, isEmpty);
  });
}
