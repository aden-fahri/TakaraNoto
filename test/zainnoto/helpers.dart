import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

class TestContext {
  TestContext({
    required this.db,
    required this.repo,
    required this.groupId,
    required this.aliceId,
    required this.bobId,
    required this.planId,
  });

  final Database db;
  final ZainNotoRepository repo;
  final String groupId;
  final String aliceId;
  final String bobId;
  final String planId;
}

/// Membuka database bersama in-memory (tabel Pribadi + `zn_*`) lewat
/// [DatabaseHelper], dan mendaftarkan pembersihan otomatis lewat
/// `addTearDown`.
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await DatabaseHelper.closeForTesting();
  DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
  addTearDown(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = null;
  });
  return DatabaseHelper.instance.database;
}

/// Opens a fresh in-memory shared database and seeds one weekly plan
/// (default 20.000/minggu) with two members: Alice & Bob.
Future<TestContext> seedWeekly({
  int amount = 20000,
  int dueDay = 7,
  String startDate = '2026-01-05',
}) async {
  final db = await openTestDatabase();

  final repo = ZainNotoRepository();
  final groupId = await repo.createGroup(name: 'Kas Futsal');
  final aliceId = await repo.addMember(
    groupId: groupId,
    name: 'Alice',
    joinedAt: '2026-01-01',
  );
  final bobId = await repo.addMember(
    groupId: groupId,
    name: 'Bob',
    joinedAt: '2026-01-01',
  );
  final planId = await repo.upsertDuesPlan(
    groupId: groupId,
    amount: amount,
    frequency: DuesFrequency.weekly,
    dueDay: dueDay,
    startDate: startDate,
  );
  return TestContext(
    db: db,
    repo: repo,
    groupId: groupId,
    aliceId: aliceId,
    bobId: bobId,
    planId: planId,
  );
}
