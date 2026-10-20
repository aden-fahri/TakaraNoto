import 'package:sqflite/sqflite.dart';

import '../zainnoto/repositories/zainnoto_repository.dart';
import '../zainnoto/models/entities.dart';

class ExampleSeed {
  ExampleSeed._();

  static Future<void> seed(Database db, {required DateTime asOf}) async {
    // Bersihkan data lama agar tidak menggandakan.
    await db.delete('zn_allocations');
    await db.delete('zn_transactions');
    await db.delete('zn_charges');
    await db.delete('zn_periods');
    await db.delete('zn_dues_plans');
    await db.delete('zn_members');
    await db.delete('zn_groups');
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('savings_goals');

    final repo = ZainNotoRepository(
      openDatabase: () async => db,
    );

    // TakaraNoto: satu tujuan tabungan.
    final savingsGoalId = await db.insert('savings_goals', {
      'title': 'Tabungan Liburan',
      'target_amount': 5000000.0,
      'created_at': '2026-07-01',
    });

    // Ambil kategori default.
    Future<int> catId(String name, String type) async {
      final rows = await db.query(
        'categories',
        columns: ['id'],
        where: 'name = ? AND type = ?',
        whereArgs: [name, type],
        limit: 1,
      );
      return rows.first['id'] as int;
    }

    final gaji = await catId('Gaji', 'income');
    final makanan = await catId('Makanan & Minuman', 'expense');
    final transport = await catId('Transportasi', 'expense');
    final tabunganCat = await catId('Tabungan', 'expense');

    // Transaksi 3 bulan (Jul, Agu, Sep 2026).
    final months = ['2026-07', '2026-08', '2026-09'];
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      await db.insert('transactions', {
        'category_id': gaji,
        'amount': 5000000.0,
        'type': 'income',
        'date': '$m-05',
        'note': 'Gaji',
      });
      await db.insert('transactions', {
        'category_id': makanan,
        'amount': 1200000.0 + i * 100000,
        'type': 'expense',
        'date': '$m-10',
        'note': 'Makan',
      });
      await db.insert('transactions', {
        'category_id': transport,
        'amount': 300000.0,
        'type': 'expense',
        'date': '$m-15',
        'note': 'Transport',
      });
      // Setor tabungan (expense is_savings) tiap bulan
      await db.insert('transactions', {
        'category_id': tabunganCat,
        'amount': 500000.0,
        'type': 'expense',
        'date': '$m-20',
        'note': 'Setor tabungan',
        'savings_goal_id': savingsGoalId,
      });
    }
    // 1 transfer
    await db.insert('transactions', {
      'category_id': (await catId('Top Up', 'expense')),
      'amount': 200000.0,
      'type': 'expense',
      'date': '2026-08-01',
      'note': 'Transfer ke E-Wallet',
      'wallet_type': 'main',
      'is_transfer': 1,
      'transfer_group': 1,
    });
    await db.insert('transactions', {
      'category_id': (await catId('Transfer Masuk', 'income')),
      'amount': 200000.0,
      'type': 'income',
      'date': '2026-08-01',
      'note': 'Transfer dari dompet utama',
      'wallet_type': 'topup',
      'is_transfer': 1,
      'transfer_group': 1,
    });

    // Anggaran untuk bulan asOf
    final ym = '${asOf.year}-${asOf.month.toString().padLeft(2, '0')}';
    await db.insert('budgets', {
      'category_id': makanan,
      'limit_amount': 1500000.0,
      'month_year': ym,
      'budget_type': 'goal',
    });

    // ZainNoto
    final groupId = await repo.createGroup(name: 'Kas RT 05');
    final names = ['Budi', 'Sari', 'Andi', 'Dewi', 'Rudi', 'Maya', 'Joko', 'Lina'];
    final memberIds = <String>[];
    for (final n in names) {
      memberIds.add(await repo.addMember(
        groupId: groupId,
        name: n,
        joinedAt: '2026-07-01',
      ));
    }
    await repo.upsertDuesPlan(
      groupId: groupId,
      amount: 50000,
      frequency: DuesFrequency.monthly,
      dueDay: 10,
      startDate: '2026-07-01',
    );
    await repo.generatePeriods(groupId: groupId, upTo: DateTime(2026, 10, 31));

    // Pembayaran
    final byName = <String, String>{
      for (var i = 0; i < names.length; i++) names[i]: memberIds[i],
    };
    // Fully paid 4 periods = 200000
    for (final n in ['Budi', 'Sari', 'Andi', 'Rudi', 'Lina']) {
      await repo.recordDuesPayment(
        groupId: groupId,
        memberId: byName[n]!,
        amount: 200000,
        date: '2026-10-10',
      );
    }
    // Maya cicil: 3 full + 25000
    await repo.recordDuesPayment(
      groupId: groupId,
      memberId: byName['Maya']!,
      amount: 175000,
      date: '2026-10-10',
    );
    // Dewi telat 2 periode: 2 full
    await repo.recordDuesPayment(
      groupId: groupId,
      memberId: byName['Dewi']!,
      amount: 100000,
      date: '2026-10-10',
    );
    // Joko telat 1 periode: 3 full
    await repo.recordDuesPayment(
      groupId: groupId,
      memberId: byName['Joko']!,
      amount: 150000,
      date: '2026-10-10',
    );
  }
}
