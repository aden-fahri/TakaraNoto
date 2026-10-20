import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('Butir 2a: hapus pembayaran mengembalikan tagihan menunggak', () async {
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
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 21));

    final txs = await db.query('zn_transactions',
        where: "type='dues' AND is_deleted=0 AND member_id=?",
        whereArgs: [ctx.aliceId]);
    expect(txs.length, 1);
    await repo.deleteTransaction(txs.first['id'] as String);

    final charges = await db.query('zn_charges',
        where: 'member_id=? AND deleted_at IS NULL', whereArgs: [ctx.aliceId]);
    for (final c in charges) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
          [c['id']]);
      expect((alloc.first['s'] as num).toInt(), 0);
    }
    final credit = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((credit.first['s'] as num).toInt(), 0);
    final kas = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) s FROM zn_transactions WHERE type='dues' AND is_deleted=0");
    expect((kas.first['s'] as num).toInt(), 0);

    final overdue = await repo.getOverdueMembers(groupId: ctx.groupId, asOf: DateTime(2026, 2, 1));
    final aliceOverdue = overdue.where((m) => m.memberId == ctx.aliceId).toList();
    expect(aliceOverdue.first.totalOverdueAmount, 60000);
    final badAlloc = await db.rawQuery(
        'SELECT COUNT(*) c FROM zn_allocations a LEFT JOIN zn_transactions t ON t.id=a.transaction_id WHERE t.is_deleted=1 OR t.id IS NULL');
    expect((badAlloc.first['c'] as num).toInt(), 0);
  });

  test('Butir 2b: dua pembayaran, hapus yang lebih lama', () async {
    final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
    final repo = ctx.repo;
    final db = ctx.db;

    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 7));
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 30000,
      date: '2026-01-05',
      idempotencyKey: 'A',
    );
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 14));
    await repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 70000,
      date: '2026-01-12',
      idempotencyKey: 'B',
    );
    await repo.generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 21));

    final txA = await db.query('zn_transactions',
        where: "client_ref='A' AND is_deleted=0");
    await repo.deleteTransaction(txA.first['id'] as String);

    final charges = await db.query('zn_charges',
        where: 'member_id=? AND deleted_at IS NULL', whereArgs: [ctx.aliceId],
        orderBy: 'period_id');
    for (final c in charges.take(3)) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
          [c['id']]);
      expect((alloc.first['s'] as num).toInt(), 20000);
    }
    final overdue = await repo.getOverdueMembers(groupId: ctx.groupId, asOf: DateTime(2026, 2, 1));
    final aliceOverdue = overdue.where((m) => m.memberId == ctx.aliceId).toList();
    expect(aliceOverdue.isEmpty || aliceOverdue.first.totalOverdueAmount == 0, isTrue);
    final credit = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((credit.first['s'] as num).toInt(), 10000);
    final bad = await db.rawQuery('''
      SELECT COUNT(*) c FROM zn_charges c JOIN zn_periods p ON p.id=c.period_id
      WHERE c.member_id=? AND c.waived=0 AND p.due_date < '2026-02-01'
      AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a JOIN zn_transactions t ON t.id=a.transaction_id AND t.is_deleted=0 WHERE a.charge_id=c.id) < c.amount_due
      AND (SELECT COALESCE(SUM(cr.amount_remaining),0) FROM zn_member_credits cr WHERE cr.member_id=c.member_id) > 0
    ''', [ctx.aliceId]);
    expect((bad.first['c'] as num).toInt(), 0);
    final txB = await db.query('zn_transactions',
        where: "client_ref='B' AND is_deleted=0");
    final allocB = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE transaction_id=?',
        [txB.first['id']]);
    final creditB = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE source_transaction_id=?',
        [txB.first['id']]);
    expect((allocB.first['s'] as num).toInt() + (creditB.first['s'] as num).toInt(), 70000);
  });
}
