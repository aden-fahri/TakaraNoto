import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/models/budget.dart';
import 'package:finflow_flutter/models/savings_goal.dart';
import 'package:finflow_flutter/models/transaction.dart';
import 'package:finflow_flutter/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<int> catId(String name, String type) async {
    final cats = await DatabaseHelper.instance.getCategories();
    return cats.firstWhere((c) => c.name == name && c.type == type).id!;
  }

  Future<void> addTx({
    required int categoryId,
    required double amount,
    required String type,
    String date = '2026-10-05',
    String wallet = 'main',
    int? goalId,
  }) async {
    await DatabaseHelper.instance.addTransaction(FinanceTransaction(
      categoryId: categoryId,
      amount: amount,
      type: type,
      date: date,
      note: '',
      walletType: wallet,
      savingsGoalId: goalId,
    ));
  }

  /// Gaji 1jt, isi E-Wallet 500rb, belanja via E-Wallet 100rb.
  Future<void> seedWalletScenario() async {
    await addTx(
      categoryId: await catId('Gaji', 'income'),
      amount: 1000000,
      type: 'income',
    );
    await DatabaseHelper.instance.addTransfer(
      toTopup: true,
      amount: 500000,
      date: '2026-10-06',
      note: 'isi saldo',
    );
    await addTx(
      categoryId: await catId('Makanan & Minuman', 'expense'),
      amount: 100000,
      type: 'expense',
      wallet: 'topup',
    );
  }

  test('A1: top up mengurangi saldo dompet utama, uang riil tidak bertambah',
      () async {
    await seedWalletScenario();

    expect(await DatabaseHelper.instance.getCumulativeBalanceUpTo('2026-10'),
        500000);
    expect(await DatabaseHelper.instance.getTopupWalletBalance(), 400000);
  });

  test('A2: belanja E-Wallet masuk statistik, anggaran, dan daftar transaksi',
      () async {
    await seedWalletScenario();

    final totals = await DatabaseHelper.instance.getMonthlyTotals('2026-10');
    expect(totals['income'], 1000000);
    expect(totals['expense'], 100000);

    final spending = await DatabaseHelper.instance.getCategorySpending('2026-10');
    expect(spending.length, 1);
    expect(spending.first['category_name'], 'Makanan & Minuman');
    expect((spending.first['amount'] as num).toDouble(), 100000);

    final foodId = await catId('Makanan & Minuman', 'expense');
    await DatabaseHelper.instance.addOrUpdateBudget(Budget(
      categoryId: foodId,
      limitAmount: 300000,
      monthYear: '2026-10',
      budgetType: 'goal',
    ));
    final budgets = await DatabaseHelper.instance.getBudgets('2026-10');
    expect(budgets.length, 1);
    expect(budgets.first.totalSpent, 100000);

    final txs = await DatabaseHelper.instance.getTransactions();
    expect(txs.where((t) => t.walletType == 'topup' && !t.isTransfer).length, 1);
    expect(txs.where((t) => t.isTransfer).length, 2);
  });

  test('A3: setoran & penarikan tabungan keluar dari income/expense', () async {
    final goalId = await DatabaseHelper.instance.addSavingsGoal(SavingsGoal(
      title: 'Dana Darurat',
      targetAmount: 5000000,
      createdAt: '2026-10-01',
    ));
    await addTx(
      categoryId: await catId('Tabungan', 'expense'),
      amount: 500000,
      type: 'expense',
      goalId: goalId,
    );
    await addTx(
      categoryId: await catId('Tarik Tabungan', 'income'),
      amount: 200000,
      type: 'income',
      goalId: goalId,
    );

    final totals = await DatabaseHelper.instance.getMonthlyTotals('2026-10');
    expect(totals['income'], 0);
    expect(totals['expense'], 0);

    expect(await DatabaseHelper.instance.getCategorySpending('2026-10'), isEmpty);
    expect(await DatabaseHelper.instance.getCategoryIncome('2026-10'), isEmpty);
    expect(await DatabaseHelper.instance.getNetSaved('2026-10'), 300000);
  });

  test('A4: menghapus target tabungan tidak mengubah laporan', () async {
    final goalId = await DatabaseHelper.instance.addSavingsGoal(SavingsGoal(
      title: 'Dana Darurat',
      targetAmount: 5000000,
      createdAt: '2026-10-01',
    ));
    await addTx(
      categoryId: await catId('Tabungan', 'expense'),
      amount: 500000,
      type: 'expense',
      goalId: goalId,
    );
    await addTx(
      categoryId: await catId('Tarik Tabungan', 'income'),
      amount: 200000,
      type: 'income',
      goalId: goalId,
    );

    await DatabaseHelper.instance.deleteSavingsGoal(goalId);

    final totals = await DatabaseHelper.instance.getMonthlyTotals('2026-10');
    expect(totals['income'], 0);
    expect(totals['expense'], 0);
    expect(await DatabaseHelper.instance.getNetSaved('2026-10'), 300000);
  });

  test('A5: anggaran kategori sama untuk bulan berbeda berhasil', () async {
    final foodId = await catId('Makanan & Minuman', 'expense');
    await DatabaseHelper.instance.addOrUpdateBudget(Budget(
      categoryId: foodId,
      limitAmount: 300000,
      monthYear: '2026-10',
      budgetType: 'goal',
    ));
    // Dulu gagal: UNIQUE(category_id) global.
    await DatabaseHelper.instance.addOrUpdateBudget(Budget(
      categoryId: foodId,
      limitAmount: 400000,
      monthYear: '2026-11',
      budgetType: 'goal',
    ));
    // Update bulan yang sama harus meng-update, bukan menduplikasi.
    await DatabaseHelper.instance.addOrUpdateBudget(Budget(
      categoryId: foodId,
      limitAmount: 350000,
      monthYear: '2026-10',
      budgetType: 'goal',
    ));

    final oct = await DatabaseHelper.instance.getBudgets('2026-10');
    expect(oct.length, 1);
    expect(oct.first.limitAmount, 350000);

    final nov = await DatabaseHelper.instance.getBudgets('2026-11');
    expect(nov.length, 1);
    expect(nov.first.limitAmount, 400000);
  });

  test('migrasi v6 -> v7: data awet, composite UNIQUE aktif, flag savings terisi',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('finflow_mig');
    addTearDown(() async {
      await DatabaseHelper.closeForTesting();
      await tempDir.delete(recursive: true);
    });
    final dbPath = p.join(tempDir.path, 'finflow.db');

    final legacy = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE NOT NULL,
              icon TEXT NOT NULL,
              color TEXT NOT NULL,
              type TEXT NOT NULL CHECK(type IN ('income', 'expense'))
            )
          ''');
          await db.execute('''
            CREATE TABLE savings_goals (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              target_amount REAL NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE budgets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER UNIQUE NOT NULL,
              limit_amount REAL NOT NULL,
              month_year TEXT NOT NULL,
              budget_type TEXT NOT NULL CHECK(budget_type IN ('daily_limit', 'goal')),
              FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
              date TEXT NOT NULL,
              note TEXT,
              savings_goal_id INTEGER,
              wallet_type TEXT DEFAULT 'main',
              is_transfer INTEGER NOT NULL DEFAULT 0,
              transfer_group INTEGER,
              FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
              FOREIGN KEY (savings_goal_id) REFERENCES savings_goals (id) ON DELETE SET NULL
            )
          ''');

          for (final cat in [
            {'name': 'Gaji', 'icon': 'banknote', 'color': '#2ecc71', 'type': 'income'},
            {'name': 'Tabungan', 'icon': 'trending_up', 'color': '#1abc9c', 'type': 'expense'},
            {'name': 'Tarik Tabungan', 'icon': 'download', 'color': '#f39c12', 'type': 'income'},
            {'name': 'Makanan & Minuman', 'icon': 'fast_food', 'color': '#ff7f50', 'type': 'expense'},
            {'name': 'Top Up', 'icon': 'payments', 'color': '#3f51b5', 'type': 'expense'},
            {'name': 'Transfer Masuk', 'icon': 'download', 'color': '#5c6bc0', 'type': 'income'},
          ]) {
            await db.insert('categories', cat);
          }
          await db.insert('budgets', {
            'category_id': 4,
            'limit_amount': 300000,
            'month_year': '2026-09',
            'budget_type': 'goal',
          });
          await db.insert('transactions', {
            'category_id': 1,
            'amount': 1000000,
            'type': 'income',
            'date': '2026-09-05',
            'note': 'gaji',
            'savings_goal_id': null,
            'wallet_type': 'main',
            'is_transfer': 0,
            'transfer_group': null,
          });
        },
      ),
    );
    await legacy.close();

    DatabaseHelper.resetForTesting();
    DatabaseHelper.debugDatabasePath = dbPath;

    // Membuka lewat DatabaseHelper memicu upgrade ke v7.
    final totals = await DatabaseHelper.instance.getMonthlyTotals('2026-09');
    expect(totals['income'], 1000000);
    expect(totals['expense'], 0);

    // Budget lama dipertahankan.
    final oldBudgets = await DatabaseHelper.instance.getBudgets('2026-09');
    expect(oldBudgets.length, 1);
    expect(oldBudgets.first.limitAmount, 300000);

    // Composite UNIQUE aktif: bulan baru untuk kategori sama berhasil.
    await DatabaseHelper.instance.addOrUpdateBudget(Budget(
      categoryId: 4,
      limitAmount: 200000,
      monthYear: '2026-10',
      budgetType: 'goal',
    ));
    expect((await DatabaseHelper.instance.getBudgets('2026-10')).length, 1);

    // Flag is_savings terisi: aliran tabungan dipisah dari statistik.
    await addTx(
      categoryId: await catId('Tabungan', 'expense'),
      amount: 500000,
      type: 'expense',
      date: '2026-10-05',
    );
    await addTx(
      categoryId: await catId('Tarik Tabungan', 'income'),
      amount: 200000,
      type: 'income',
      date: '2026-10-06',
    );
    final octTotals = await DatabaseHelper.instance.getMonthlyTotals('2026-10');
    expect(octTotals['income'], 0);
    expect(octTotals['expense'], 0);
    expect(await DatabaseHelper.instance.getNetSaved('2026-10'), 300000);
  });
}
