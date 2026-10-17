import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/budget.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Web in-memory fallback database
  static final List<Category> _webCategories = [];
  static final List<FinanceTransaction> _webTransactions = [];
  static final List<SavingsGoal> _webSavingsGoals = [];
  static final List<Budget> _webBudgets = [];
  static int _webIdCounter = 1;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Database is not supported on Web');
    }
    if (_database != null) return _database!;
    _database = await _initDB('finflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 6, // Upgrade to version 6
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS budgets');
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS categories');
      await db.execute('DROP TABLE IF EXISTS savings_goals');
      await _createDB(db, newVersion);
    }
    if (oldVersion < 4) {
      // Recreate budgets table to restore the budget feature in version 4
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER UNIQUE NOT NULL,
          limit_amount REAL NOT NULL,
          month_year TEXT NOT NULL,
          budget_type TEXT NOT NULL CHECK(budget_type IN ('daily_limit', 'goal')),
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      if (!await _columnExists(db, 'transactions', 'wallet_type')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN wallet_type TEXT DEFAULT 'main'");
      }
      // Seed default category "Top Up"
      final existing = await db.query('categories', where: 'name = ?', whereArgs: ['Top Up']);
      if (existing.isEmpty) {
        await db.insert('categories', {
          'name': 'Top Up',
          'icon': 'payments',
          'color': '#3f51b5',
          'type': 'expense'
        });
      }
    }
    if (oldVersion < 6) {
      // Transfer support between the main wallet and the e-wallet
      if (!await _columnExists(db, 'transactions', 'is_transfer')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN is_transfer INTEGER NOT NULL DEFAULT 0');
      }
      if (!await _columnExists(db, 'transactions', 'transfer_group')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN transfer_group INTEGER');
      }

      // Seed the receiving category used by transfer pairs
      final tmExisting = await db.query('categories', where: 'name = ?', whereArgs: ['Transfer Masuk']);
      if (tmExisting.isEmpty) {
        await db.insert('categories', {
          'name': 'Transfer Masuk',
          'icon': 'download',
          'color': '#5c6bc0',
          'type': 'income'
        });
      }

      // Migrate legacy top ups: main-wallet "Top Up" expenses become transfer pairs
      // so previous e-wallet balances stay identical while no longer counting as
      // regular expenses in statistics and budgets.
      final topupCat = await db.query('categories',
          where: 'name = ? AND type = ?', whereArgs: ['Top Up', 'expense'], limit: 1);
      final tmCat = await db.query('categories',
          where: 'name = ? AND type = ?', whereArgs: ['Transfer Masuk', 'income'], limit: 1);
      if (topupCat.isNotEmpty && tmCat.isNotEmpty) {
        final topupCatId = topupCat.first['id'] as int;
        final tmCatId = tmCat.first['id'] as int;
        final legacy = await db.query(
          'transactions',
          where: "wallet_type = 'main' AND category_id = ? AND type = 'expense' AND is_transfer = 0",
          whereArgs: [topupCatId],
        );
        for (final row in legacy) {
          final legacyId = row['id'] as int;
          final amount = (row['amount'] as num).toDouble();
          final rawNote = (row['note'] as String? ?? '').trim();
          await db.update(
            'transactions',
            {'is_transfer': 1, 'transfer_group': legacyId},
            where: 'id = ?',
            whereArgs: [legacyId],
          );
          await db.insert('transactions', {
            'category_id': tmCatId,
            'amount': amount,
            'type': 'income',
            'date': row['date'],
            'note': rawNote.isNotEmpty ? rawNote : 'Top Up Saldo',
            'savings_goal_id': null,
            'wallet_type': 'topup',
            'is_transfer': 1,
            'transfer_group': legacyId,
          });
        }
      }
    }
  }

  Future _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense'))
      )
    ''');

    // Savings Goals Table
    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Budgets Table
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

    // Transactions Table
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

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future _seedDefaultCategories(Database db) async {
    final List<Map<String, String>> defaultCategories = [
      {'name': 'Makanan & Minuman', 'icon': 'fast_food', 'color': '#ff7f50', 'type': 'expense'},
      {'name': 'Transportasi', 'icon': 'car', 'color': '#3498db', 'type': 'expense'},
      {'name': 'Belanja', 'icon': 'cart', 'color': '#9b59b6', 'type': 'expense'},
      {'name': 'Hiburan', 'icon': 'gamepad_2', 'color': '#e74c3c', 'type': 'expense'},
      {'name': 'Kesehatan', 'icon': 'heart_pulse', 'color': '#2ecc71', 'type': 'expense'},
      {'name': 'Tagihan & Utilitas', 'icon': 'receipt', 'color': '#f1c40f', 'type': 'expense'},
      {'name': 'Tabungan', 'icon': 'trending_up', 'color': '#1abc9c', 'type': 'expense'}, // Special category
      {'name': 'Tarik Tabungan', 'icon': 'download', 'color': '#f39c12', 'type': 'income'},
      {'name': 'Gaji', 'icon': 'banknote', 'color': '#2ecc71', 'type': 'income'},
      {'name': 'Investasi', 'icon': 'trending_up', 'color': '#1abc9c', 'type': 'income'},
      {'name': 'Saku & Hibah', 'icon': 'gift', 'color': '#fd79a8', 'type': 'income'},
      {'name': 'Transfer Masuk', 'icon': 'download', 'color': '#5c6bc0', 'type': 'income'},
      {'name': 'Top Up', 'icon': 'payments', 'color': '#3f51b5', 'type': 'expense'},
      {'name': 'Lain-lain', 'icon': 'ellipsis', 'color': '#95a5a6', 'type': 'expense'}
    ];

    for (final cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  void _initWebCategories() {
    if (_webCategories.isEmpty) {
      final List<Map<String, dynamic>> defaultCategories = [
        {'id': 1, 'name': 'Makanan & Minuman', 'icon': 'fast_food', 'color': '#ff7f50', 'type': 'expense'},
        {'id': 2, 'name': 'Transportasi', 'icon': 'car', 'color': '#3498db', 'type': 'expense'},
        {'id': 3, 'name': 'Belanja', 'icon': 'cart', 'color': '#9b59b6', 'type': 'expense'},
        {'id': 4, 'name': 'Hiburan', 'icon': 'gamepad_2', 'color': '#e74c3c', 'type': 'expense'},
        {'id': 5, 'name': 'Kesehatan', 'icon': 'heart_pulse', 'color': '#2ecc71', 'type': 'expense'},
        {'id': 6, 'name': 'Tagihan & Utilitas', 'icon': 'receipt', 'color': '#f1c40f', 'type': 'expense'},
        {'id': 7, 'name': 'Tabungan', 'icon': 'trending_up', 'color': '#1abc9c', 'type': 'expense'},
        {'id': 12, 'name': 'Tarik Tabungan', 'icon': 'download', 'color': '#f39c12', 'type': 'income'},
        {'id': 8, 'name': 'Gaji', 'icon': 'banknote', 'color': '#2ecc71', 'type': 'income'},
        {'id': 9, 'name': 'Investasi', 'icon': 'trending_up', 'color': '#1abc9c', 'type': 'income'},
        {'id': 10, 'name': 'Saku & Hibah', 'icon': 'gift', 'color': '#fd79a8', 'type': 'income'},
        {'id': 14, 'name': 'Transfer Masuk', 'icon': 'download', 'color': '#5c6bc0', 'type': 'income'},
        {'id': 13, 'name': 'Top Up', 'icon': 'payments', 'color': '#3f51b5', 'type': 'expense'},
        {'id': 11, 'name': 'Lain-lain', 'icon': 'ellipsis', 'color': '#95a5a6', 'type': 'expense'}
      ];
      for (final cat in defaultCategories) {
        _webCategories.add(Category.fromMap(cat));
      }
      _webIdCounter = 15;
    }
  }

  // --- Categories CRUD ---
  
  Future<List<Category>> getCategories() async {
    if (kIsWeb) {
      _initWebCategories();
      final sorted = List<Category>.from(_webCategories);
      sorted.sort((a, b) => a.name.compareTo(b.name));
      return sorted;
    }

    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'name ASC');
    if (result.isEmpty) {
      await _seedDefaultCategories(db);
      final refetched = await db.query('categories', orderBy: 'name ASC');
      return refetched.map((json) => Category.fromMap(json)).toList();
    }
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> addCategory(Category category) async {
    if (kIsWeb) {
      _initWebCategories();
      final newId = _webIdCounter++;
      final newCat = Category(
        id: newId,
        name: category.name,
        icon: category.icon,
        color: category.color,
        type: category.type,
      );
      _webCategories.add(newCat);
      return newId;
    }

    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> deleteCategory(int id) async {
    if (kIsWeb) {
      _webCategories.removeWhere((c) => c.id == id);
      _webTransactions.removeWhere((t) => t.categoryId == id);
      return 1;
    }

    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transactions CRUD ---

  Future<List<FinanceTransaction>> getTransactions({String walletType = 'main'}) async {
    if (kIsWeb) {
      _initWebCategories();
      final joined = _webTransactions
          .where((tx) => tx.walletType == walletType)
          .map((tx) {
            final cat = _webCategories.firstWhere(
              (c) => c.id == tx.categoryId,
              orElse: () => Category(name: 'Tanpa Kategori', icon: 'ellipsis', color: '#95a5a6', type: 'expense'),
            );
            return FinanceTransaction(
              id: tx.id,
              categoryId: tx.categoryId,
              amount: tx.amount,
              type: tx.type,
              date: tx.date,
              note: tx.note,
              savingsGoalId: tx.savingsGoalId,
              walletType: tx.walletType,
              categoryName: cat.name,
              categoryIcon: cat.icon,
              categoryColor: cat.color,
            );
          }).toList();
      
      joined.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return joined;
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.icon as category_icon, c.color as category_color 
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.wallet_type = ?
      ORDER BY t.date DESC, t.id DESC
    ''', [walletType]);
    return result.map((json) => FinanceTransaction.fromMap(json)).toList();
  }

  Future<int> addTransaction(FinanceTransaction transaction) async {
    if (kIsWeb) {
      final newId = _webIdCounter++;
      final tx = FinanceTransaction(
        id: newId,
        categoryId: transaction.categoryId,
        amount: transaction.amount,
        type: transaction.type,
        date: transaction.date,
        note: transaction.note,
        savingsGoalId: transaction.savingsGoalId,
        walletType: transaction.walletType,
        isTransfer: transaction.isTransfer,
        transferGroup: transaction.transferGroup,
      );
      _webTransactions.add(tx);
      return newId;
    }

    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  /// Creates a transfer pair between the main wallet and the e-wallet.
  /// Both rows share a [transferGroup] and are flagged as transfers so they
  /// are excluded from income/expense statistics and budgets.
  Future<void> addTransfer({
    required bool toTopup,
    required double amount,
    required String date,
    required String note,
  }) async {
    const outCatName = 'Top Up';
    const inCatName = 'Transfer Masuk';
    final fromWallet = toTopup ? 'main' : 'topup';
    final toWallet = toTopup ? 'topup' : 'main';

    if (kIsWeb) {
      _initWebCategories();
      final outCat = _webCategories.firstWhere((c) => c.name == outCatName && c.type == 'expense',
          orElse: () => Category(name: outCatName, icon: 'payments', color: '#3f51b5', type: 'expense'));
      final inCat = _webCategories.firstWhere((c) => c.name == inCatName && c.type == 'income',
          orElse: () => Category(name: inCatName, icon: 'download', color: '#5c6bc0', type: 'income'));
      final group = _webIdCounter;
      _webTransactions.add(FinanceTransaction(
        id: _webIdCounter++,
        categoryId: outCat.id ?? 0,
        amount: amount,
        type: 'expense',
        date: date,
        note: note,
        walletType: fromWallet,
        isTransfer: true,
        transferGroup: group,
      ));
      _webTransactions.add(FinanceTransaction(
        id: _webIdCounter++,
        categoryId: inCat.id ?? 0,
        amount: amount,
        type: 'income',
        date: date,
        note: note,
        walletType: toWallet,
        isTransfer: true,
        transferGroup: group,
      ));
      return;
    }

    final db = await instance.database;
    final outCat = await db.query('categories',
        where: 'name = ? AND type = ?', whereArgs: [outCatName, 'expense'], limit: 1);
    final inCat = await db.query('categories',
        where: 'name = ? AND type = ?', whereArgs: [inCatName, 'income'], limit: 1);
    if (outCat.isEmpty || inCat.isEmpty) return;
    final outCatId = outCat.first['id'] as int;
    final inCatId = inCat.first['id'] as int;
    final group = DateTime.now().microsecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'category_id': outCatId,
        'amount': amount,
        'type': 'expense',
        'date': date,
        'note': note,
        'savings_goal_id': null,
        'wallet_type': fromWallet,
        'is_transfer': 1,
        'transfer_group': group,
      });
      await txn.insert('transactions', {
        'category_id': inCatId,
        'amount': amount,
        'type': 'income',
        'date': date,
        'note': note,
        'savings_goal_id': null,
        'wallet_type': toWallet,
        'is_transfer': 1,
        'transfer_group': group,
      });
    });
  }

  Future<int> deleteTransaction(int id) async {
    if (kIsWeb) {
      final idx = _webTransactions.indexWhere((t) => t.id == id);
      if (idx != -1) {
        final tx = _webTransactions[idx];
        if (tx.isTransfer && tx.transferGroup != null) {
          _webTransactions.removeWhere((t) => t.transferGroup == tx.transferGroup);
          return 2;
        }
      }
      _webTransactions.removeWhere((t) => t.id == id);
      return 1;
    }

    final db = await instance.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final row = rows.first;
      final isTransfer = (row['is_transfer'] as int? ?? 0) == 1;
      final group = row['transfer_group'] as int?;
      if (isTransfer && group != null) {
        return await db.delete('transactions', where: 'transfer_group = ?', whereArgs: [group]);
      }
    }
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction(FinanceTransaction transaction) async {
    if (kIsWeb) {
      final idx = _webTransactions.indexWhere((t) => t.id == transaction.id);
      if (idx != -1) {
        _webTransactions[idx] = transaction;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // --- Savings Goals CRUD ---

  Future<List<SavingsGoal>> getSavingsGoals() async {
    if (kIsWeb) {
      return _webSavingsGoals.map((g) {
        final currentAmount = _webTransactions
            .where((t) => t.savingsGoalId == g.id)
            .fold(0.0, (sum, t) => sum + (t.type == 'expense' ? t.amount : (t.type == 'income' ? -t.amount : 0.0)));
        return SavingsGoal(
          id: g.id,
          title: g.title,
          targetAmount: g.targetAmount,
          createdAt: g.createdAt,
          currentAmount: currentAmount,
        );
      }).toList();
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT g.*, COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount WHEN t.type = 'income' THEN -t.amount ELSE 0 END), 0) as current_amount
      FROM savings_goals g
      LEFT JOIN transactions t ON t.savings_goal_id = g.id
      GROUP BY g.id
      ORDER BY g.id DESC
    ''');
    return result.map((json) => SavingsGoal.fromMap(json)).toList();
  }

  Future<int> addSavingsGoal(SavingsGoal goal) async {
    if (kIsWeb) {
      final newId = _webIdCounter++;
      final g = SavingsGoal(
        id: newId,
        title: goal.title,
        targetAmount: goal.targetAmount,
        createdAt: goal.createdAt,
      );
      _webSavingsGoals.add(g);
      return newId;
    }

    final db = await instance.database;
    return await db.insert('savings_goals', goal.toMap());
  }

  Future<int> deleteSavingsGoal(int id) async {
    if (kIsWeb) {
      _webSavingsGoals.removeWhere((g) => g.id == id);
      // CASCADE nullify in-memory transactions savings_goal_id
      for (int i = 0; i < _webTransactions.length; i++) {
        if (_webTransactions[i].savingsGoalId == id) {
          final old = _webTransactions[i];
          _webTransactions[i] = FinanceTransaction(
            id: old.id,
            categoryId: old.categoryId,
            amount: old.amount,
            type: old.type,
            date: old.date,
            note: old.note,
            savingsGoalId: null,
            walletType: old.walletType,
            isTransfer: old.isTransfer,
            transferGroup: old.transferGroup,
          );
        }
      }
      return 1;
    }

    final db = await instance.database;
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSavingsGoal(SavingsGoal goal) async {
    if (kIsWeb) {
      final idx = _webSavingsGoals.indexWhere((g) => g.id == goal.id);
      if (idx != -1) {
        _webSavingsGoals[idx] = goal;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  // --- Aggregate Queries ---

  Future<List<Map<String, dynamic>>> getCategorySpending(String monthYear) async {
    if (kIsWeb) {
      _initWebCategories();
      final Map<int, double> spending = {};
      for (final tx in _webTransactions) {
        if (tx.date.startsWith(monthYear) && tx.walletType == 'main' && !tx.isTransfer) {
          if (tx.type == 'expense') {
            spending[tx.categoryId] = (spending[tx.categoryId] ?? 0.0) + tx.amount;
          } else if (tx.type == 'income' && tx.savingsGoalId != null) {
            spending[tx.categoryId] = (spending[tx.categoryId] ?? 0.0) - tx.amount;
          }
        }
      }
      final List<Map<String, dynamic>> result = [];
      spending.forEach((catId, amount) {
        if (amount > 0) {
          final cat = _webCategories.firstWhere((c) => c.id == catId,
              orElse: () => Category(name: 'Tanpa Kategori', icon: 'ellipsis', color: '#95a5a6', type: 'expense'));
          result.add({
            'category_name': cat.name,
            'color': cat.color,
            'amount': amount,
          });
        }
      });
      result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      return result;
    }

    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.name as category_name, c.color, 
             SUM(CASE WHEN t.type = 'expense' THEN t.amount WHEN (t.type = 'income' AND t.savings_goal_id IS NOT NULL) THEN -t.amount ELSE 0 END) as amount
      FROM transactions t
      INNER JOIN categories c ON t.category_id = c.id
      WHERE (t.type = 'expense' OR (t.type = 'income' AND t.savings_goal_id IS NOT NULL)) AND substr(t.date, 1, 7) = ? AND t.wallet_type = 'main' AND t.is_transfer = 0
      GROUP BY t.category_id
      HAVING amount > 0
      ORDER BY amount DESC
    ''', [monthYear]);
  }

  Future<Map<String, double>> getMonthlyTotals(String monthYear) async {
    if (kIsWeb) {
      double income = 0;
      double expense = 0;
      for (final tx in _webTransactions) {
        if (tx.date.startsWith(monthYear) && tx.walletType == 'main' && !tx.isTransfer) {
          if (tx.type == 'income') {
            if (tx.savingsGoalId != null) {
              expense -= tx.amount;
            } else {
              income += tx.amount;
            }
          } else {
            expense += tx.amount;
          }
        }
      }
      return {
        'income': income,
        'expense': expense,
      };
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN (type = 'income' AND savings_goal_id IS NULL) THEN amount ELSE 0 END), 0) as income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount WHEN (type = 'income' AND savings_goal_id IS NOT NULL) THEN -amount ELSE 0 END), 0) as expense
      FROM transactions
      WHERE substr(date, 1, 7) = ? AND wallet_type = 'main' AND is_transfer = 0
    ''', [monthYear]);

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'income': (row['income'] as num).toDouble(),
        'expense': (row['expense'] as num).toDouble(),
      };
    }
    return {'income': 0.0, 'expense': 0.0};
  }

  Future<List<Map<String, dynamic>>> getCategoryIncome(String monthYear) async {
    if (kIsWeb) {
      _initWebCategories();
      final Map<int, double> incomeByCat = {};
      for (final tx in _webTransactions) {
        if (tx.date.startsWith(monthYear) &&
            tx.walletType == 'main' &&
            !tx.isTransfer &&
            tx.type == 'income' &&
            tx.savingsGoalId == null) {
          incomeByCat[tx.categoryId] = (incomeByCat[tx.categoryId] ?? 0.0) + tx.amount;
        }
      }
      final List<Map<String, dynamic>> result = [];
      incomeByCat.forEach((catId, amount) {
        if (amount > 0) {
          final cat = _webCategories.firstWhere((c) => c.id == catId,
              orElse: () => Category(name: 'Tanpa Kategori', icon: 'ellipsis', color: '#95a5a6', type: 'income'));
          result.add({
            'category_name': cat.name,
            'color': cat.color,
            'amount': amount,
          });
        }
      });
      result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      return result;
    }

    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.name as category_name, c.color, SUM(t.amount) as amount
      FROM transactions t
      INNER JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'income' AND t.savings_goal_id IS NULL AND t.is_transfer = 0
        AND t.wallet_type = 'main' AND substr(t.date, 1, 7) = ?
      GROUP BY t.category_id
      HAVING amount > 0
      ORDER BY amount DESC
    ''', [monthYear]);
  }

  // --- Budgets CRUD ---

  Future<List<Budget>> getBudgets(String monthYear) async {
    if (kIsWeb) {
      _initWebCategories();
      return _webBudgets.where((b) => b.monthYear == monthYear).map((b) {
        final totalSpent = _webTransactions
            .where((t) => t.categoryId == b.categoryId && (t.type == 'expense' || (t.type == 'income' && t.savingsGoalId != null)) && t.date.startsWith(monthYear) && t.walletType == 'main' && !t.isTransfer)
            .fold(0.0, (sum, t) => sum + (t.type == 'expense' ? t.amount : -t.amount));
        
        final cat = _webCategories.firstWhere(
          (c) => c.id == b.categoryId,
          orElse: () => Category(name: 'Tanpa Kategori', icon: 'ellipsis', color: '#95a5a6', type: 'expense'),
        );

        return Budget(
          id: b.id,
          categoryId: b.categoryId,
          limitAmount: b.limitAmount,
          monthYear: b.monthYear,
          budgetType: b.budgetType,
          categoryName: cat.name,
          categoryColor: cat.color,
          categoryIcon: cat.icon,
          totalSpent: totalSpent,
        );
      }).toList();
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT b.*, c.name as category_name, c.color as category_color, c.icon as category_icon,
             COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount WHEN (t.type = 'income' AND t.savings_goal_id IS NOT NULL) THEN -t.amount ELSE 0 END), 0) as total_spent
      FROM budgets b
      INNER JOIN categories c ON b.category_id = c.id
      LEFT JOIN transactions t ON t.category_id = b.category_id 
        AND (t.type = 'expense' OR (t.type = 'income' AND t.savings_goal_id IS NOT NULL))
        AND substr(t.date, 1, 7) = b.month_year
        AND t.wallet_type = 'main'
        AND t.is_transfer = 0
      WHERE b.month_year = ?
      GROUP BY b.id
    ''', [monthYear]);
    return result.map((json) => Budget.fromMap(json)).toList();
  }

  Future<int> addOrUpdateBudget(Budget budget) async {
    if (kIsWeb) {
      final idx = _webBudgets.indexWhere((b) => b.categoryId == budget.categoryId && b.monthYear == budget.monthYear);
      if (idx != -1) {
        final existing = _webBudgets[idx];
        _webBudgets[idx] = Budget(
          id: existing.id,
          categoryId: budget.categoryId,
          limitAmount: budget.limitAmount,
          monthYear: budget.monthYear,
          budgetType: budget.budgetType,
        );
        return existing.id!;
      } else {
        final newId = _webIdCounter++;
        _webBudgets.add(Budget(
          id: newId,
          categoryId: budget.categoryId,
          limitAmount: budget.limitAmount,
          monthYear: budget.monthYear,
          budgetType: budget.budgetType,
        ));
        return newId;
      }
    }

    final db = await instance.database;
    final existing = await db.query(
      'budgets',
      where: 'category_id = ? AND month_year = ?',
      whereArgs: [budget.categoryId, budget.monthYear],
    );
    if (existing.isNotEmpty) {
      final budgetId = existing.first['id'] as int;
      await db.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [budgetId],
      );
      return budgetId;
    } else {
      return await db.insert('budgets', budget.toMap());
    }
  }

  Future<int> deleteBudget(int id) async {
    if (kIsWeb) {
      _webBudgets.removeWhere((b) => b.id == id);
      return 1;
    }

    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTopupWalletBalance() async {
    if (kIsWeb) {
      double balance = 0.0;
      for (final tx in _webTransactions) {
        if (tx.walletType != 'topup') continue;
        balance += tx.type == 'income' ? tx.amount : -tx.amount;
      }
      return balance;
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) as total
      FROM transactions
      WHERE wallet_type = 'topup'
    ''');
    return (result.first['total'] as num).toDouble();
  }

  Future<List<FinanceTransaction>> getTopupTransactions() async {
    if (kIsWeb) {
      _initWebCategories();
      final List<FinanceTransaction> list = [];
      for (final tx in _webTransactions) {
        if (tx.walletType != 'topup') continue;
        final cat = _webCategories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => Category(name: 'Tanpa Kategori', icon: 'ellipsis', color: '#95a5a6', type: 'expense'),
        );
        list.add(FinanceTransaction(
          id: tx.id,
          categoryId: tx.categoryId,
          amount: tx.amount,
          type: tx.type,
          date: tx.date,
          note: tx.note,
          walletType: tx.walletType,
          isTransfer: tx.isTransfer,
          transferGroup: tx.transferGroup,
          categoryName: cat.name,
          categoryIcon: cat.icon,
          categoryColor: cat.color,
        ));
      }
      list.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return list;
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.icon as category_icon, c.color as category_color 
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.wallet_type = 'topup'
      ORDER BY t.date DESC, t.id DESC
    ''');

    return result.map((row) => FinanceTransaction.fromMap(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getMonthlyNetBalanceHistory() async {
    if (kIsWeb) {
      final Map<String, Map<String, double>> groups = {};
      for (final tx in _webTransactions) {
        if (tx.walletType == 'main' && !tx.isTransfer) {
          final m = tx.date.substring(0, 7);
          groups.putIfAbsent(m, () => {'income': 0.0, 'expense': 0.0});
          if (tx.type == 'income') {
            if (tx.savingsGoalId != null) {
              groups[m]!['expense'] = groups[m]!['expense']! - tx.amount;
            } else {
              groups[m]!['income'] = groups[m]!['income']! + tx.amount;
            }
          } else {
            groups[m]!['expense'] = groups[m]!['expense']! + tx.amount;
          }
        }
      }
      final List<Map<String, dynamic>> list = [];
      groups.forEach((m, data) {
        final inc = data['income']!;
        final exp = data['expense']!;
        list.add({
          'month': m,
          'income': inc,
          'expense': exp,
          'balance': inc - exp,
        });
      });
      list.sort((a, b) => b['month'].compareTo(a['month']));
      return list;
    }

    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        substr(date, 1, 7) as month,
        COALESCE(SUM(CASE WHEN (type = 'income' AND savings_goal_id IS NULL) THEN amount ELSE 0 END), 0) as income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount WHEN (type = 'income' AND savings_goal_id IS NOT NULL) THEN -amount ELSE 0 END), 0) as expense
      FROM transactions
      WHERE wallet_type = 'main' AND is_transfer = 0
      GROUP BY month
      ORDER BY month DESC
    ''');

    return result.map((row) {
      final inc = (row['income'] as num).toDouble();
      final exp = (row['expense'] as num).toDouble();
      return {
        'month': row['month'] as String,
        'income': inc,
        'expense': exp,
        'balance': inc - exp,
      };
    }).toList();
  }
}
