import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/zainnoto/db/zainnoto_database.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

class TestContext {
  TestContext({
    required this.database,
    required this.repo,
    required this.groupId,
    required this.aliceId,
    required this.bobId,
    required this.planId,
  });

  final ZainNotoDatabase database;
  final ZainNotoRepository repo;
  final String groupId;
  final String aliceId;
  final String bobId;
  final String planId;
}

/// Opens a fresh in-memory ZainNoto database and seeds one weekly plan
/// (default 20.000/minggu) with two members: Alice & Bob.
Future<TestContext> seedWeekly({
  int amount = 20000,
  int dueDay = 7,
  String startDate = '2026-01-05',
}) async {
  sqfliteFfiInit();
  final database = ZainNotoDatabase();
  await database.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  addTearDown(database.close);

  final repo = ZainNotoRepository(database);
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
    database: database,
    repo: repo,
    groupId: groupId,
    aliceId: aliceId,
    bobId: bobId,
    planId: planId,
  );
}
