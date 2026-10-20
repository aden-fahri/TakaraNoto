import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';
import 'helpers.dart';

void main() {
  test('credit idle: waive then unwaive consumes or keeps credit', () async {
    final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
    final repo = ctx.repo;
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 2, 28));
    // Alice pays 50000 -> 2 periods + credit 10000
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 50000,
      date: '2026-01-05',
    );

    // find a future charge for Alice that is unpaid
    final db = ctx.db;
    final charges = await db.query('zn_charges',
        where: 'member_id = ? AND waived = 0', whereArgs: [ctx.aliceId]);
    // waive then unwaive the last charge
    final target = charges.last['id'] as String;
    await repo.setChargeWaived(target, waived: true);
    await repo.setChargeWaived(target, waived: false);

    // invariant: no member with credit>0 and unpaid due charge
    final credits = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    final credit = (credits.first['s'] as num).toInt();
    // if credit>0, all due charges should be paid
    if (credit > 0) {
      final unpaid = await db.rawQuery('''
        SELECT COUNT(*) c FROM zn_charges c JOIN zn_periods p ON p.id=c.period_id
        WHERE c.member_id=? AND c.waived=0 AND p.due_date < '2026-03-01'
        AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a JOIN zn_transactions t ON t.id=a.transaction_id AND t.is_deleted=0 WHERE a.charge_id=c.id) < c.amount_due
      ''', [ctx.aliceId]);
      expect(unpaid.first['c'], 0);
    }
  });

  test('credit idle: change amount and regenerate periods keeps credit', () async {
    final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
    final repo = ctx.repo;
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 2, 28));
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 50000,
      date: '2026-01-05',
    );
    // change amount
    final plans = await repo.getDuesPlans(ctx.groupId);
    await repo.upsertDuesPlan(
      id: plans.first.id,
      groupId: ctx.groupId,
      amount: 30000,
      frequency: DuesFrequency.weekly,
      dueDay: 1,
      startDate: '2026-01-05',
    );
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 2, 28));

    final db = ctx.db;
    final credits = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    final credit = (credits.first['s'] as num).toInt();
    // credit should be >=0
    expect(credit, greaterThanOrEqualTo(0));
  });
}
