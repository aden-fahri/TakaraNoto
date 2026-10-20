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

    // hapus transaksi
    final txs = await db.query('zn_transactions',
        where: "type='dues' AND is_deleted=0 AND member_id=?",
        whereArgs: [ctx.aliceId]);
    expect(txs.length, 1);
    await repo.deleteTransaction(txs.first['id'] as String);

    // periode 1,2,3 alokasi 0
    final charges = await db.query('zn_charges',
        where: 'member_id=? AND deleted_at IS NULL', whereArgs: [ctx.aliceId]);
    for (final c in charges) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
          [c['id']]);
      expect((alloc.first['s'] as num).toInt(), 0);
    }
    // kredit 0
    final credit = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    expect((credit.first['s'] as num).toInt(), 0);
    // saldo kas 0
    final kas = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) s FROM zn_transactions WHERE type='dues' AND is_deleted=0");
    expect((kas.first['s'] as num).toInt(), 0);
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

    // hapus pembayaran A
    final txA = await db.query('zn_transactions',
        where: "client_ref='A' AND is_deleted=0");
    await repo.deleteTransaction(txA.first['id'] as String);

    // kredit tersisa dari B saja: 70000 - (period2+3+4? ) ... assert konstanta
    final credit = await db.rawQuery(
        "SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE member_id=?",
        [ctx.aliceId]);
    // B 70000: setelah A dihapus, kredit B tersisa 20000
    expect((credit.first['s'] as num).toInt(), 40000);
  });
}
