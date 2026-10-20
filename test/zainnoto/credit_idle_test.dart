import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'helpers.dart';

void main() {
  test('Scenario A: unwaive memakai kredit', () async {
    final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
    final repo = ctx.repo;
    final db = ctx.db;

    // 1. hanya periode pertama
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 7));

    // period1 charge id
    final p1 = await db.query('zn_charges',
        where: 'member_id = ?', whereArgs: [ctx.aliceId]);
    final charge1 = p1.first['id'] as String;

    // 2. waive period1 sebelum bayar
    await repo.setChargeWaived(charge1, waived: true);

    // 3. Alice bayar 100000 -> seluruhnya jadi kredit (period1 waived)
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 100000,
      date: '2026-01-05',
    );
    final creditAfterPay = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((creditAfterPay.first['s'] as num).toInt(), 100000);

    // 4. generate periode 2 (credit terpakai untuk periode2)
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 14));
    final creditAfterGen = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((creditAfterGen.first['s'] as num).toInt(), 80000);

    // 5. unwaive period1 -> harus terbayar lewat kredit
    await repo.setChargeWaived(charge1, waived: false);

    final alloc = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
        [charge1]);
    expect((alloc.first['s'] as num).toInt(), 20000);

    final creditNow = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((creditNow.first['s'] as num).toInt(), 60000);
  });

  test('Scenario B: nominal iuran naik dengan kredit utuh', () async {
    final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
    final repo = ctx.repo;
    final db = ctx.db;

    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 7));
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 100000,
      date: '2026-01-05',
    );
    // credit 80000

    final plans = await repo.getDuesPlans(ctx.groupId);
    await repo.upsertDuesPlan(
      id: plans.first.id,
      groupId: ctx.groupId,
      amount: 30000,
      frequency: DuesFrequency.weekly,
      dueDay: 1,
      startDate: '2026-01-05',
    );
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 14));

    final credit = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    // 80000 - 30000 = 50000 (period2 costs 30000)
    expect((credit.first['s'] as num).toInt(), 50000);
  });
}
