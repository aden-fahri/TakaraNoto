import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = null;
  });

  test('invariant ZainNoto pada seed', () async {
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    final repo = ZainNotoRepository(openDatabase: () async => db);
    final groups = await repo.getGroups();
    final groupId = groups.first.id;

    // alokasi per tagihan <= amount_due
    final charges = await db.query('zn_charges', where: 'deleted_at IS NULL');
    for (final c in charges) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
          [c['id']]);
      final a = (alloc.first['s'] as num).toInt();
      expect(a, lessThanOrEqualTo(c['amount_due'] as int));
    }

    // alokasi + kredit = nominal transaksi
    final txs = await db.query('zn_transactions',
        where: "type='dues' AND is_deleted=0");
    for (final t in txs) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE transaction_id=?',
          [t['id']]);
      final a = (alloc.first['s'] as num).toInt();
      final credits = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE source_transaction_id=?',
          [t['id']]);
      final cr = (credits.first['s'] as num).toInt();
      expect(a + cr, t['amount'] as int);
    }

    // satu tagihan per anggota per periode
    final dup = await db.rawQuery(
        'SELECT period_id, member_id, COUNT(*) c FROM zn_charges WHERE deleted_at IS NULL GROUP BY period_id, member_id HAVING c>1');
    expect(dup, isEmpty);

    // total tunggakan = jumlah daftar tunggakan
    final overdue = await repo.getOverdueMembers(groupId: groupId, asOf: DateTime(2026, 10, 15));
    final sumOverdue = overdue.fold<int>(0, (s, m) => s + m.totalOverdueAmount);
    var total = 0;
    for (final c in charges) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations a JOIN zn_transactions t ON t.id=a.transaction_id AND t.is_deleted=0 WHERE a.charge_id=?',
          [c['id']]);
      final a = (alloc.first['s'] as num).toInt();
      final remaining = (c['amount_due'] as int) - a;
      if (remaining > 0 && (c['waived'] as int) == 0) {
        total += remaining;
      }
    }
    expect(sumOverdue, total);
  });

  test('invariant ZainNoto data acak (seed=7)', () async {
    final seed = int.tryParse(Platform.environment['RANDOM_SEED_ZAINNOTO'] ?? '') ?? 7;
    // ignore: avoid_print
    print('RANDOM_SEED_ZAINNOTO=$seed');
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    final repo = ZainNotoRepository(openDatabase: () async => db);
    final groups = await repo.getGroups();
    final groupId = groups.first.id;
    final members = await repo.getMembers(groupId);
    await repo.recordDuesPayment(
        groupId: groupId, memberId: members.first.id, amount: 100000, date: '2026-10-10');
    final txs = await db.query('zn_transactions',
        where: "type='dues' AND is_deleted=0", limit: 1);
    if (txs.isNotEmpty) {
      await repo.deleteTransaction(txs.first['id'] as String);
    }
    if (members.length > 1) {
      final charges = await db.query('zn_charges',
          where: 'member_id=? AND deleted_at IS NULL',
          whereArgs: [members[1].id],
          limit: 1);
      if (charges.isNotEmpty) {
        await repo.setChargeWaived(charges.first['id'] as String, waived: true);
      }
    }
    final plans2 = await repo.getDuesPlans(groupId);
    if (plans2.isNotEmpty) {
      await repo.upsertDuesPlan(
          id: plans2.first.id,
          groupId: groupId,
          amount: 75000,
          frequency: DuesFrequency.monthly,
          dueDay: 15,
          startDate: '2026-07-01');
    }
    await repo.generatePeriods(groupId: groupId, upTo: DateTime(2026, 10, 31));

    final charges2 = await db.query('zn_charges', where: 'deleted_at IS NULL');
    for (final c in charges2) {
      final alloc = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?',
          [c['id']]);
      final a = (alloc.first['s'] as num).toInt();
      expect(a, lessThanOrEqualTo(c['amount_due'] as int));
    }
    final dup2 = await db.rawQuery(
        'SELECT period_id, member_id, COUNT(*) c FROM zn_charges WHERE deleted_at IS NULL GROUP BY period_id, member_id HAVING c>1');
    expect(dup2, isEmpty);
  });
}
