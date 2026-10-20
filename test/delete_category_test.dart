import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/models/budget.dart';
import 'package:finflow_flutter/models/category.dart';
import 'package:finflow_flutter/models/transaction.dart';
import 'package:finflow_flutter/services/database_helper.dart';

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

  test('hitung transaksi dan anggaran terdampak kategori', () async {
    final dbh = DatabaseHelper.instance;
    final catId = await dbh.addCategory(Category(
      name: 'TestCat',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: catId,
      amount: 1000,
      type: 'expense',
      date: '2026-08-01',
      note: 'x',
    ));
    await dbh.addOrUpdateBudget(Budget(
      categoryId: catId,
      limitAmount: 5000,
      monthYear: '2026-08',
      budgetType: 'goal',
    ));
    final usage = await dbh.categoryUsage(catId);
    expect(usage.transactions, 1);
    expect(usage.budgets, 1);
  });

  test('hapus kategori dengan transaksi tidak menghilangkan transaksi', () async {
    final dbh = DatabaseHelper.instance;
    final catId = await dbh.addCategory(Category(
      name: 'TestCat2',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: catId,
      amount: 1000,
      type: 'expense',
      date: '2026-08-01',
      note: 'x',
    ));
    expect(() => dbh.deleteCategory(catId), throwsStateError);
    final txs = await dbh.getTransactions();
    expect(txs.length, 1);
  });

  test('reassignCategory memindahkan transaksi dan anggaran', () async {
    final dbh = DatabaseHelper.instance;
    final fromId = await dbh.addCategory(Category(
      name: 'From',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final toId = await dbh.addCategory(Category(
      name: 'To',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: fromId,
      amount: 1000,
      type: 'expense',
      date: '2026-08-01',
      note: 'x',
    ));
    await dbh.addOrUpdateBudget(Budget(
      categoryId: fromId,
      limitAmount: 5000,
      monthYear: '2026-08',
      budgetType: 'goal',
    ));
    await dbh.reassignCategory(fromId, toId);
    final txs = await dbh.getTransactions();
    expect(txs.first.categoryId, toId);
    final budgets = await dbh.getBudgets('2026-08');
    expect(budgets.any((b) => b.categoryId == toId), isTrue);
    expect(budgets.any((b) => b.categoryId == fromId), isFalse);
  });

  test('reassignCategory menolak tipe atau savings berbeda', () async {
    final dbh = DatabaseHelper.instance;
    final fromId = await dbh.addCategory(Category(
      name: 'From2',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final toId = await dbh.addCategory(Category(
      name: 'To2',
      icon: 'cart',
      color: '#9b59b6',
      type: 'income',
    ));
    expect(() => dbh.reassignCategory(fromId, toId), throwsStateError);
  });

  test('reassignCategory menolak bentrok anggaran bulan sama', () async {
    final dbh = DatabaseHelper.instance;
    final fromId = await dbh.addCategory(Category(
      name: 'From3',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final toId = await dbh.addCategory(Category(
      name: 'To3',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addOrUpdateBudget(Budget(
      categoryId: fromId,
      limitAmount: 5000,
      monthYear: '2026-08',
      budgetType: 'goal',
    ));
    await dbh.addOrUpdateBudget(Budget(
      categoryId: toId,
      limitAmount: 3000,
      monthYear: '2026-08',
      budgetType: 'goal',
    ));
    expect(() => dbh.reassignCategory(fromId, toId), throwsStateError);
  });

  test('total dan donat identik setelah reassign', () async {
    final dbh = DatabaseHelper.instance;
    final fromId = await dbh.addCategory(Category(
      name: 'FromX',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final toId = await dbh.addCategory(Category(
      name: 'ToX',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final otherId = await dbh.addCategory(Category(
      name: 'OtherX',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: fromId,
      amount: 1000,
      type: 'expense',
      date: '2026-07-10',
      note: 'a',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: fromId,
      amount: 2000,
      type: 'expense',
      date: '2026-08-10',
      note: 'b',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: otherId,
      amount: 500,
      type: 'expense',
      date: '2026-08-10',
      note: 'c',
    ));

    Future<Map<String, dynamic>> snapshot() async {
      final totals = await dbh.getMonthlyTotals('2026-08');
      final spending = await dbh.getCategorySpending('2026-08');
      return {
        'expense': totals['expense'],
        'rows': spending,
      };
    }

    final before = await snapshot();
    await dbh.reassignCategory(fromId, toId);
    final after = await snapshot();

    expect(after['expense'], before['expense']);
    // donat: baris from hilang, to bertambah 2000, other tetap 500
    final beforeRows = before['rows'] as List<Map<String, dynamic>>;
    final afterRows = after['rows'] as List<Map<String, dynamic>>;
    double amt(List<Map<String, dynamic>> rows, String name) {
      final r = rows.where((e) => e['category_name'] == name).toList();
      return r.isEmpty ? 0 : (r.first['amount'] as num).toDouble();
    }

    expect(amt(afterRows, 'FromX'), 0);
    expect(amt(afterRows, 'ToX'), 2000);
    expect(amt(afterRows, 'OtherX'), 500);
    expect(amt(beforeRows, 'OtherX'), 500);
  });

  test('setelah reassign deleteCategory berhasil', () async {
    final dbh = DatabaseHelper.instance;
    final fromId = await dbh.addCategory(Category(
      name: 'From4',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    final toId = await dbh.addCategory(Category(
      name: 'To4',
      icon: 'cart',
      color: '#9b59b6',
      type: 'expense',
    ));
    await dbh.addTransaction(FinanceTransaction(
      categoryId: fromId,
      amount: 1000,
      type: 'expense',
      date: '2026-08-01',
      note: 'x',
    ));
    await dbh.reassignCategory(fromId, toId);
    await dbh.deleteCategory(fromId);
    final cats = await dbh.getCategories();
    expect(cats.any((c) => c.id == fromId), isFalse);
  });
}

