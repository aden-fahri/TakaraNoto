import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/services/example_seed.dart';

Future<Map<int, Map<String, Object?>>> _cats(Database db) async {
  final rows = await db.query('categories');
  return {for (final r in rows) r['id'] as int: r};
}

Future<void> _assertTransfer(Database db) async {
  final rows = await db.rawQuery(
      'SELECT transfer_group, COUNT(*) c, MIN(amount) mn, MAX(amount) mx FROM transactions WHERE transfer_group IS NOT NULL GROUP BY transfer_group');
  for (final r in rows) {
    expect(r['c'], 2, reason: 'transfer_group ${r['transfer_group']} harus 2 sisi');
    expect(r['mn'], r['mx'], reason: 'dua sisi transfer harus sama nilainya');
  }
}

Future<void> _assertDonut(Database db, String month) async {
  final totalRow = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) s FROM transactions WHERE type='expense' AND substr(date,1,7)=? AND is_transfer=0",
      [month]);
  final catRows = await db.rawQuery(
      "SELECT COALESCE(SUM(t.amount),0) s FROM transactions t JOIN categories c ON c.id=t.category_id WHERE t.type='expense' AND substr(t.date,1,7)=? AND t.is_transfer=0 GROUP BY c.id",
      [month]);
  var catSum = 0.0;
  for (final r in catRows) {
    catSum += (r['s'] as num).toDouble();
  }
  expect(catSum, (totalRow.first['s'] as num).toDouble(),
      reason: 'donat kategori harus = total pengeluaran');
}

Future<void> _assertSavingsDelete(Database db) async {
  final before = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE -amount END),0) s FROM transactions WHERE substr(date,1,7)='2026-08' AND is_transfer=0");
  final goals = await db.query('savings_goals');
  if (goals.isNotEmpty) {
    await db.delete('savings_goals',
        where: 'id=?', whereArgs: [goals.first['id']]);
  }
  final after = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE -amount END),0) s FROM transactions WHERE substr(date,1,7)='2026-08' AND is_transfer=0");
  expect(after.first['s'], before.first['s'],
      reason: 'hapus tujuan tabungan tidak boleh ubah total bulanan');
}

Future<void> _assertBalance(Database db) async {
  final cats = await _cats(db);
  bool isSavings(int catId) =>
      (cats[catId]?['is_savings'] as int? ?? 0) == 1;

  final txs = await db.query('transactions', where: 'is_transfer=0');
  double main = 0, ewallet = 0, net = 0, tabungan = 0;
  for (final t in txs) {
    final amt = (t['amount'] as num).toDouble();
    final type = t['type'] as String;
    final wallet = t['wallet_type'] as String? ?? 'main';
    final catId = t['category_id'] as int;
    final sign = type == 'income' ? 1.0 : -1.0;
    if (isSavings(catId)) {
      if (type == 'expense') {
        tabungan += amt; // setor
      } else {
        tabungan -= amt; // tarik
      }
      // uang tetap berpindah dompet: main/ewallet berkurang/bertambah
      if (wallet == 'topup') {
        ewallet += sign * amt;
      } else {
        main += sign * amt;
      }
      continue;
    }
    net += sign * amt;
    if (wallet == 'topup') {
      ewallet += sign * amt;
    } else {
      main += sign * amt;
    }
  }
  // tabungan balance = setor - tarik (net saved) stored as tabungan
  expect(main + ewallet + tabungan, closeTo(net, 0.001),
      reason: 'saldo utama+ewallet+tabungan = pemasukan bersih (tanpa transfer/tabungan)');
}

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

  test('invariant TakaraNoto pada seed', () async {
    final db = await DatabaseHelper.instance.database;
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    await _assertTransfer(db);
    await _assertDonut(db, '2026-08');
    await _assertSavingsDelete(db);
    // reseed after delete
    await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
    await _assertBalance(db);
  });

  test('invariant TakaraNoto pada data acak (seed=42)', () async {
    final seed = int.tryParse(Platform.environment['RANDOM_SEED_TAKARANOTO'] ?? '') ?? 42;
    // ignore: avoid_print
    print('RANDOM_SEED_TAKARANOTO=$seed');
    final rng = Random(seed);
    final db = await DatabaseHelper.instance.database;
    // base categories already seeded by DB creation
    // generate random transactions
    final cats = await db.query('categories');
    final incomeCats =
        cats.where((c) => c['type'] == 'income').map((c) => c['id'] as int).toList();
    final expenseCats =
        cats.where((c) => c['type'] == 'expense').map((c) => c['id'] as int).toList();
    final months = ['2026-07', '2026-08', '2026-09'];
    for (var i = 0; i < 40; i++) {
      final m = months[rng.nextInt(months.length)];
      final day = (rng.nextInt(28) + 1).toString().padLeft(2, '0');
      final isIncome = rng.nextBool();
      final cat = isIncome
          ? incomeCats[rng.nextInt(incomeCats.length)]
          : expenseCats[rng.nextInt(expenseCats.length)];
      await db.insert('transactions', {
        'category_id': cat,
        'amount': (rng.nextInt(9) + 1) * 10000.0,
        'type': isIncome ? 'income' : 'expense',
        'date': '$m-$day',
        'note': 'rand',
        'wallet_type': rng.nextBool() ? 'main' : 'topup',
        'is_transfer': 0,
      });
    }
    // one transfer pair
    await db.insert('transactions', {
      'category_id': expenseCats.first,
      'amount': 12345.0,
      'type': 'expense',
      'date': '2026-08-10',
      'note': 'tr',
      'wallet_type': 'main',
      'is_transfer': 1,
      'transfer_group': 999,
    });
    await db.insert('transactions', {
      'category_id': incomeCats.first,
      'amount': 12345.0,
      'type': 'income',
      'date': '2026-08-10',
      'note': 'tr',
      'wallet_type': 'topup',
      'is_transfer': 1,
      'transfer_group': 999,
    });
    // savings goal
    final gid = await db.insert('savings_goals', {
      'title': 'G',
      'target_amount': 1000.0,
      'created_at': '2026-07-01',
    });
    await db.insert('transactions', {
      'category_id': expenseCats.first,
      'amount': 5000.0,
      'type': 'expense',
      'date': '2026-08-11',
      'note': 'setor',
      'wallet_type': 'main',
      'is_transfer': 0,
      'savings_goal_id': gid,
    });

    await _assertTransfer(db);
    await _assertDonut(db, '2026-08');
    await _assertBalance(db);
  });
}
