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

