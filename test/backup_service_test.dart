import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/services/backup_service.dart';
import 'package:finflow_flutter/zainnoto/db/zainnoto_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final nowIso = DateTime.utc(2026, 1, 7).toIso8601String();

  /// Database gabungan tiruan: tabel Pribadi minimal + tabel `zn_*` asli
  /// (schema Fase 3), persis seperti `finflow.db` setelah v8.
  Future<Database> openMergedLike() {
    return databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE categories ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE transactions ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'category_id INTEGER, amount REAL NOT NULL, note TEXT)',
          );
          await db.execute(
            'CREATE TABLE budgets ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'category_id INTEGER UNIQUE NOT NULL, limit_amount REAL NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE savings_goals ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, target REAL NOT NULL)',
          );
          await createZainNotoSchema(db);
        },
      ),
    );
  }

  Future<Database> seedAll() async {
    final db = await openMergedLike();
    await db.insert('categories', {'name': 'Makanan'});
    await db.insert('transactions', {
      'category_id': 1,
      'amount': 25000.0,
      'note': 'Nasi goreng',
    });
    await db.insert('budgets', {'category_id': 1, 'limit_amount': 500000.0});
    await db.insert('savings_goals', {'name': 'Liburan', 'target': 1000000.0});

    await db.insert('zn_groups', {
      'id': 'g1',
      'name': 'Kas Futsal',
      'icon_index': 0,
      'color_hex': '#059669',
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_members', {
      'id': 'm1',
      'group_id': 'g1',
      'name': 'Alice',
      'joined_at': '2026-01-05',
      'status': 'active',
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_dues_plans', {
      'id': 'p1',
      'group_id': 'g1',
      'amount': 20000,
      'frequency': 'weekly',
      'due_day': 7,
      'start_date': '2026-01-05',
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_periods', {
      'id': 'pe1',
      'group_id': 'g1',
      'dues_plan_id': 'p1',
      'label': 'Minggu 1',
      'start_date': '2026-01-05',
      'end_date': '2026-01-11',
      'due_date': '2026-01-11',
      'amount_snapshot': 20000,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_charges', {
      'id': 'c1',
      'member_id': 'm1',
      'period_id': 'pe1',
      'amount_due': 20000,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_transactions', {
      'id': 't1',
      'group_id': 'g1',
      'member_id': 'm1',
      'type': 'dues',
      'amount': 20000,
      'date': '2026-01-07',
      'is_deleted': 0,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await db.insert('zn_allocations', {
      'id': 'a1',
      'transaction_id': 't1',
      'charge_id': 'c1',
      'amount_allocated': 20000,
      'created_at': nowIso,
    });
    await db.insert('zn_member_credits', {
      'id': 'cr1',
      'member_id': 'm1',
      'source_transaction_id': 't1',
      'amount_remaining': 5000,
      'created_at': nowIso,
    });
    await db.insert('zn_audit_log', {
      'entity': 'transactions',
      'entity_id': 't1',
      'action': 'create',
      'created_at': nowIso,
    });
    return db;
  }

  BackupService buildService({
    required Future<Database> Function() openDatabase,
  }) {
    return BackupService(
      openDatabase: openDatabase,
      tempDirectory: () async => Directory.systemTemp,
    );
  }

  test('round-trip: ekspor lalu impor mengembalikan seluruh data', () async {
    SharedPreferences.setMockInitialValues({
      'custom_primary_color': 0xFF381932,
      'custom_background_color': 0xFFFFF3E6,
    });

    // Source data.
    final sourceDb = await seedAll();
    final source = buildService(openDatabase: () async => sourceDb);
    final payload = await source.collect();
    expect(payload['app'], BackupService.appMarker);

    // Restore into a fresh merged database.
    final targetDb = await openMergedLike();
    final target = buildService(openDatabase: () async => targetDb);
    final result = await target.restoreFromJson(payload);

    expect(result.finflowRows, 4);
    expect(result.zainnotoRows, 9);
    expect(result.safetyBackupPath, isNotEmpty);

    expect(await targetDb.query('categories'), hasLength(1));
    expect(await targetDb.query('transactions'), hasLength(1));
    expect(await targetDb.query('budgets'), hasLength(1));
    expect(await targetDb.query('savings_goals'), hasLength(1));

    expect(await targetDb.query('zn_groups'), hasLength(1));
    expect(await targetDb.query('zn_members'), hasLength(1));
    expect(await targetDb.query('zn_charges'), hasLength(1));
    expect(await targetDb.query('zn_allocations'), hasLength(1));
    expect(await targetDb.query('zn_member_credits'), hasLength(1));
    expect(await targetDb.query('zn_audit_log'), hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('custom_primary_color'), 0xFF381932);
    expect(prefs.getInt('custom_background_color'), 0xFFFFF3E6);
  });

  test('impor mengganti data lama, bukan menambah', () async {
    SharedPreferences.setMockInitialValues({});

    final sourceDb = await seedAll();
    final source = buildService(openDatabase: () async => sourceDb);
    final payload = await source.collect();

    // Target already has different data.
    final targetDb = await openMergedLike();
    await targetDb.insert('categories', {'name': 'Data Lama'});
    await targetDb.insert('categories', {'name': 'Data Lama 2'});
    final target = buildService(openDatabase: () async => targetDb);

    await target.restoreFromJson(payload);

    final categories = await targetDb.query('categories');
    expect(categories, hasLength(1));
    expect(categories.single['name'], 'Makanan');
  });

  test('menolak file yang bukan backup TakaraNoto', () {
    final service = buildService(
      openDatabase: () async => throw UnimplementedError(),
    );

    final validation = service.validate({'app': 'aplikasi-lain', 'version': 1});
    expect(validation.isValid, isFalse);
    expect(validation.error, contains('bukan backup'));
  });

  test('menolak versi backup yang lebih baru', () {
    final service = buildService(
      openDatabase: () async => throw UnimplementedError(),
    );

    final validation = service.validate({
      'app': BackupService.appMarker,
      'version': BackupService.backupVersion + 1,
      'finflow': <String, Object?>{},
      'zainnoto': <String, Object?>{},
    });
    expect(validation.isValid, isFalse);
    expect(validation.error, contains('Versi backup'));
  });

  test('menolak struktur backup yang tidak lengkap', () {
    final service = buildService(
      openDatabase: () async => throw UnimplementedError(),
    );

    final validation = service.validate({
      'app': BackupService.appMarker,
      'version': BackupService.backupVersion,
    });
    expect(validation.isValid, isFalse);
    expect(validation.error, contains('tidak lengkap'));
  });
}
