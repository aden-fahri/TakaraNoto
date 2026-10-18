import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  test('unique index mencegah tagihan ganda per periode & anggota', () async {
    final ctx = await seedWeekly();
    await ctx.repo
        .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
    final db = ctx.db;
    final charge = (await db.query('zn_charges', limit: 1)).single;

    await expectLater(
      db.insert('zn_charges', {...charge, 'id': 'dup-charge'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('foreign key mencegah anggota dengan grup tidak dikenal', () async {
    final ctx = await seedWeekly();
    final db = ctx.db;

    await expectLater(
      db.insert('zn_members', {
        'id': 'member-x',
        'group_id': 'group-tidak-ada',
        'name': 'X',
        'joined_at': '2026-01-01',
        'status': 'active',
        'created_at': 'now',
        'updated_at': 'now',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('check constraint menolak nominal nol', () async {
    final ctx = await seedWeekly();
    final db = ctx.db;

    await expectLater(
      db.insert('zn_transactions', {
        'id': 'tx-x',
        'group_id': ctx.groupId,
        'type': 'expense',
        'amount': 0,
        'date': '2026-01-01',
        'is_deleted': 0,
        'created_at': 'now',
        'updated_at': 'now',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('unique index mencegah alokasi ganda untuk transaksi & tagihan sama',
      () async {
    final ctx = await seedWeekly();
    await ctx.repo
        .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
    final txId = await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 10000,
      date: '2026-01-05',
    );
    final allocations = await ctx.repo.getAllocations(txId);
    final db = ctx.db;

    await expectLater(
      db.insert('zn_allocations', {
        'id': 'alloc-x',
        'transaction_id': txId,
        'charge_id': allocations.single.chargeId,
        'amount_allocated': 1,
        'created_at': 'now',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('idempotency key ganda tidak membuat transaksi kedua', () async {
    final ctx = await seedWeekly();
    await ctx.repo
        .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));

    await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.aliceId,
      amount: 20000,
      date: '2026-01-05',
      idempotencyKey: 'same-key',
    );
    await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.bobId,
      amount: 20000,
      date: '2026-01-05',
      idempotencyKey: 'same-key',
    );

    expect(await ctx.repo.getTransactions(ctx.groupId), hasLength(1));
  });
}
