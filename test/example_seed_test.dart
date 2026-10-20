import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

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

  test('seed example: 8 anggota dan status campuran', () async {
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));

    final repo = ZainNotoRepository(openDatabase: () async => db);
    final groups = await repo.getGroups();
    expect(groups.length, 1);
    final members = await repo.getMembers(groups.first.id);
    expect(members.length, 8);

    // Status: 3 charge belum lunas (Dewi 2 + Joko 1), 1 cicil (Maya).
    final unpaid = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM zn_charges ch WHERE ch.waived=0 AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a WHERE a.charge_id=ch.id) < ch.amount_due");
    expect(unpaid.first['c'], 4);
    final partial = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM zn_charges ch WHERE ch.waived=0 AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a WHERE a.charge_id=ch.id) > 0 AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a WHERE a.charge_id=ch.id) < ch.amount_due");
    expect(partial.first['c'], 1);

    // Saldo kas = total pembayaran iuran (1.425.000), bukan mockup 2.350.000.
    final kas = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS s FROM zn_transactions WHERE type='dues' AND is_deleted=0");
    expect((kas.first['s'] as num).toInt(), 1425000);

    // jalankan dua kali tanpa duplikasi
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    final groups2 = await repo.getGroups();
    expect(groups2.length, 1);
    final members2 = await repo.getMembers(groups2.first.id);
    expect(members2.length, 8);
  });
}
