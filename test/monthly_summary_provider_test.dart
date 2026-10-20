import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/models/transaction.dart';
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
    DatabaseHelper.debugMonthlySummaryGate = null;
  });

  tearDown(() async {
    await DatabaseHelper.closeForTesting();
    DatabaseHelper.debugDatabasePath = null;
    DatabaseHelper.debugFailMonthlySummary = false;
    DatabaseHelper.debugMonthlySummaryGate = null;
  });

  test('balapan: hasil akhir milik bulan kedua', () async {
    final dbh = DatabaseHelper.instance;
    // ensure categories
    final cats = await dbh.getCategories();
    final expenseCat = cats.firstWhere((c) => c.type == 'expense').id!;
    await dbh.addTransaction(FinanceTransaction(
      categoryId: expenseCat,
      amount: 1000,
      type: 'expense',
      date: '2026-07-10',
      note: 'jul',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: expenseCat,
      amount: 2000,
      type: 'expense',
      date: '2026-08-10',
      note: 'aug',
    ));

    // gate for first refresh (July)
    final gate = Completer<void>();
    DatabaseHelper.debugMonthlySummaryGate = gate;

    final provider = FinanceProvider();
    // init refresh runs for current month (now). change to July then block
    await Future.delayed(const Duration(milliseconds: 50));
    // trigger July refresh (will block)
    provider.changeMonth('2026-07');
    await Future.delayed(const Duration(milliseconds: 50));

    // release gate for any pending? keep blocked; now trigger August without gate
    DatabaseHelper.debugMonthlySummaryGate = null;
    provider.changeMonth('2026-08');
    await Future.delayed(const Duration(milliseconds: 200));

    // release July (stale) gate
    gate.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    expect(provider.currentMonth, '2026-08');
    expect(provider.monthlyTotals['expense'], 2000.0);
  });

  test('kegagalan refresh mempertahankan semua state lama', () async {
    final dbh = DatabaseHelper.instance;
    final cats = await dbh.getCategories();
    final expenseCat = cats.firstWhere((c) => c.type == 'expense').id!;
    await dbh.addTransaction(FinanceTransaction(
      categoryId: expenseCat,
      amount: 1234,
      type: 'expense',
      date: '2026-07-10',
      note: 'jul',
    ));

    final provider = FinanceProvider();
    await Future.delayed(const Duration(milliseconds: 50));
    provider.changeMonth('2026-07');
    await Future.delayed(const Duration(milliseconds: 200));

    final beforeTotals = Map<String, double>.from(provider.monthlyTotals);
    final beforeSpending = List<Map<String, dynamic>>.from(provider.categorySpending);
    final beforeIncome = provider.categoryIncome.length;
    final beforeBudgets = provider.budgets.length;
    final beforeCumulative = provider.cumulativeBalance;

    DatabaseHelper.debugFailMonthlySummary = true;
    provider.changeMonth('2026-08');
    await Future.delayed(const Duration(milliseconds: 200));

    expect(provider.error, isNotNull);
    expect(provider.monthlyTotals, beforeTotals);
    expect(provider.categorySpending, beforeSpending);
    expect(provider.categoryIncome.length, beforeIncome);
    expect(provider.budgets.length, beforeBudgets);
    expect(provider.cumulativeBalance, beforeCumulative);
    DatabaseHelper.debugFailMonthlySummary = false;
  });
}
