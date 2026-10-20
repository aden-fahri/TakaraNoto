import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/providers/finance_provider.dart';
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

  test('Gerbang 1: angka dashboard/statistik sesuai hitungan manual', () async {
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));

    final p = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 100));

    // July
    p.changeMonth('2026-07');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(p.monthlyTotals['income'], 5000000.0);
    expect(p.monthlyTotals['expense'], 1500000.0);
    expect(p.cumulativeBalance, 3000000.0);
    expect(p.topupBalance, 0.0);
    expect(p.totalSaved, 500000.0);
    final julySpending = p.categorySpending;
    expect(julySpending.firstWhere((e) => e['category_name'] == 'Makanan & Minuman')['amount'], 1200000.0);
    expect(julySpending.firstWhere((e) => e['category_name'] == 'Transportasi')['amount'], 300000.0);

    // August
    p.changeMonth('2026-08');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(p.monthlyTotals['income'], 5000000.0);
    expect(p.monthlyTotals['expense'], 1600000.0);
    expect(p.cumulativeBalance, 5700000.0);
    expect(p.topupBalance, 200000.0);
    expect(p.totalSaved, 1000000.0);
    final augSpending = p.categorySpending;
    expect(augSpending.firstWhere((e) => e['category_name'] == 'Makanan & Minuman')['amount'], 1300000.0);
    expect(augSpending.firstWhere((e) => e['category_name'] == 'Transportasi')['amount'], 300000.0);

    // September
    p.changeMonth('2026-09');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(p.monthlyTotals['income'], 5000000.0);
    expect(p.monthlyTotals['expense'], 1700000.0);
    expect(p.cumulativeBalance, 8500000.0);
    expect(p.topupBalance, 200000.0);
    expect(p.totalSaved, 1500000.0);
    final sepSpending = p.categorySpending;
    expect(sepSpending.firstWhere((e) => e['category_name'] == 'Makanan & Minuman')['amount'], 1400000.0);
    expect(sepSpending.firstWhere((e) => e['category_name'] == 'Transportasi')['amount'], 300000.0);

    // Budget October
    p.changeMonth('2026-10');
    await Future.delayed(const Duration(milliseconds: 200));
    final budgets = p.budgets;
    final makananBudget = budgets.firstWhere((b) => b.categoryName == 'Makanan & Minuman');
    expect(makananBudget.limitAmount, 1500000.0);
  });
}
