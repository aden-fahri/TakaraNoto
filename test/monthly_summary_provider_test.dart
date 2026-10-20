import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/providers/finance_provider.dart';
import 'package:finflow_flutter/services/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = inMemoryDatabasePath;
    DatabaseHelper.debugFailMonthlySummary = false;
  });

  tearDown(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = null;
    DatabaseHelper.debugFailMonthlySummary = false;
  });

  test('refresh monthly details final state milik bulan terakhir', () async {
    final p = FinanceProvider();
    // allow init
    await Future.delayed(const Duration(milliseconds: 50));
    p.changeMonth('2026-07');
    await Future.delayed(const Duration(milliseconds: 10));
    p.changeMonth('2026-08');
    // wait
    await Future.delayed(const Duration(milliseconds: 200));
    expect(p.currentMonth, '2026-08');
    expect(p.error, isNull);
  });

  test('kegagalan refresh mengekspos error dan tidak partial', () async {
    final p = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 50));
    final beforeTotals = Map<String, double>.from(p.monthlyTotals);
    DatabaseHelper.debugFailMonthlySummary = true;
    p.changeMonth('2026-07');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(p.error, isNotNull);
    // totals unchanged (partial not applied)
    expect(p.monthlyTotals, beforeTotals);
    DatabaseHelper.debugFailMonthlySummary = false;
  });
}
