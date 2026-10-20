import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/services/example_seed.dart';

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
  test('debug savings', () async {
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    final rows = await db.rawQuery(
        "SELECT t.amount, c.name, c.is_savings, t.type FROM transactions t JOIN categories c ON c.id=t.category_id WHERE c.name='Tabungan'");
    // ignore: avoid_print
    print('SAVINGS_ROWS=$rows');
    final net = await DatabaseHelper.instance.getCumulativeNetSavedUpTo('2026-08');
    // ignore: avoid_print
    print('NET_SAVED_UP_TO=$net');
  });
}
