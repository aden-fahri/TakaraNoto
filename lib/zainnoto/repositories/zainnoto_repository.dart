import 'dart:convert';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../services/database_helper.dart';
import '../logic/allocation.dart';
import '../logic/dues_status.dart';
import '../logic/period_generator.dart';
import '../models/derived.dart';
import '../models/entities.dart';
import '../utils/dates.dart';

/// Data access + write operations for ZainNoto.
///
/// All multi-step writes (record / edit / delete payment, period generation)
/// run inside a single `db.transaction`, so a failure leaves no partial state.
/// Every insert/update/delete of user data is mirrored into `zn_audit_log`.
///
/// Sejak Fase 3, tabel ZainNoto (`zn_*`) hidup di database yang sama dengan
/// mode Pribadi (`finflow.db`) sehingga koneksi dibagi lewat [DatabaseHelper].
class ZainNotoRepository {
  ZainNotoRepository({Uuid? uuid, Future<Database> Function()? openDatabase})
    : _uuid = uuid ?? const Uuid(),
      _openDatabase = openDatabase ?? (() => DatabaseHelper.instance.database);

  final Uuid _uuid;
  final Future<Database> Function() _openDatabase;

  Future<Database> get _db => _openDatabase();

  String _newId() => _uuid.v4();

  // ── Groups ────────────────────────────────────────────────────────────────

  Future<String> createGroup({
    required String name,
    String? description,
    int iconIndex = 0,
    String colorHex = '#059669',
  }) async {
    final db = await _db;
    final id = _newId();
    final now = nowIso();
    final row = <String, Object?>{
      'id': id,
      'name': name,
      'description': description,
      'icon_index': iconIndex,
      'color_hex': colorHex,
      'created_at': now,
      'updated_at': now,
    };
    await db.transaction((txn) async {
      await txn.insert('zn_groups', row);
      await _audit(
        txn,
        entity: 'group',
        entityId: id,
        action: 'insert',
        newMap: row,
      );
    });
    return id;
  }

  Future<List<Group>> getGroups() async {
    final db = await _db;
    final rows = await db.query(
      'zn_groups',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(Group.fromMap).toList();
  }

  Future<void> updateGroup({
    required String id,
    String? name,
    String? description,
    int? iconIndex,
    String? colorHex,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'zn_groups', id);
      if (old == null) throw StateError('Grup tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'name': name ?? old['name'],
        'description': description ?? old['description'],
        'icon_index': iconIndex ?? old['icon_index'],
        'color_hex': colorHex ?? old['color_hex'],
        'updated_at': now,
      };
      await txn.update('zn_groups', updated, where: 'id = ?', whereArgs: [id]);
      await _audit(
        txn,
        entity: 'group',
        entityId: id,
        action: 'update',
        oldMap: old,
        newMap: {...old, ...updated},
      );
    });
  }

  Future<void> softDeleteGroup(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'zn_groups', id);
      if (old == null) return;
      final now = nowIso();
      await txn.update(
        'zn_groups',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(
        txn,
        entity: 'group',
        entityId: id,
        action: 'delete',
        oldMap: old,
      );
    });
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<String> addMember({
    required String groupId,
    required String name,
    String? phoneNumber,
    required String joinedAt,
  }) async {
    final db = await _db;
    final id = _newId();
    final now = nowIso();
    final row = <String, Object?>{
      'id': id,
      'group_id': groupId,
      'name': name,
      'phone_number': phoneNumber,
      'joined_at': joinedAt,
      'status': MemberStatus.active.dbValue,
      'created_at': now,
      'updated_at': now,
    };
    await db.transaction((txn) async {
      await txn.insert('zn_members', row);
      await _audit(
        txn,
        entity: 'member',
        entityId: id,
        action: 'insert',
        newMap: row,
      );

      // Backfill charges only for periods that end on/after the join date, so
      // new members never owe periods that ended before they joined.
      final periods = await txn.query(
        'zn_periods',
        where: 'group_id = ? AND deleted_at IS NULL AND end_date >= ?',
        whereArgs: [groupId, joinedAt],
      );
      for (final p in periods) {
        await txn.insert('zn_charges', {
          'id': _newId(),
          'member_id': id,
          'period_id': p['id'],
          'amount_due': p['amount_snapshot'],
          'waived': 0,
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return id;
  }

  Future<List<Member>> getMembers(
    String groupId, {
    bool includeInactive = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'zn_members',
      where: includeInactive
          ? 'group_id = ? AND deleted_at IS NULL'
          : 'group_id = ? AND deleted_at IS NULL AND status = ?',
      whereArgs: includeInactive
          ? [groupId]
          : [groupId, MemberStatus.active.dbValue],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<void> updateMember({
    required String id,
    String? name,
    String? phoneNumber,
    MemberStatus? status,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'zn_members', id);
      if (old == null) throw StateError('Anggota tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'name': name ?? old['name'],
        'phone_number': phoneNumber ?? old['phone_number'],
        'status': status?.dbValue ?? old['status'],
        'updated_at': now,
      };
      await txn.update('zn_members', updated, where: 'id = ?', whereArgs: [id]);
      await _audit(
        txn,
        entity: 'member',
        entityId: id,
        action: 'update',
        oldMap: old,
        newMap: {...old, ...updated},
      );
    });
  }

  Future<void> softDeleteMember(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'zn_members', id);
      if (old == null) return;
      final now = nowIso();
      await txn.update(
        'zn_members',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(
        txn,
        entity: 'member',
        entityId: id,
        action: 'delete',
        oldMap: old,
      );
    });
  }

  // ── Dues plans ────────────────────────────────────────────────────────────

  Future<String> upsertDuesPlan({
    String? id,
    required String groupId,
    required int amount,
    required DuesFrequency frequency,
    required int dueDay,
    required String startDate,
  }) async {
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Nominal tidak boleh negatif',
      );
    }
    final maxDueDay = frequency == DuesFrequency.weekly ? 7 : 28;
    if (dueDay < 1 || dueDay > maxDueDay) {
      throw ArgumentError.value(
        dueDay,
        'dueDay',
        frequency == DuesFrequency.weekly
            ? 'Jatuh tempo mingguan harus hari 1-7'
            : 'Jatuh tempo bulanan harus tanggal 1-28',
      );
    }
    final parsedStart = DateTime.tryParse(startDate);
    if (parsedStart == null) {
      throw ArgumentError.value(
        startDate,
        'startDate',
        'Tanggal mulai tidak valid (format YYYY-MM-DD)',
      );
    }
    final normalizedStart = dateToStr(dateOnly(parsedStart));

    final db = await _db;
    final now = nowIso();
    return db.transaction((txn) async {
      if (id == null) {
        // Only one active plan per group: the UI always edits the existing
        // plan, so an insert here means a double tap or a caller bug.
        final existing = await txn.query(
          'zn_dues_plans',
          columns: ['id'],
          where: 'group_id = ? AND deleted_at IS NULL',
          whereArgs: [groupId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError(
            'Grup ini sudah memiliki rencana iuran aktif. Ubah rencana yang ada.',
          );
        }
        final newId = _newId();
        final row = <String, Object?>{
          'id': newId,
          'group_id': groupId,
          'amount': amount,
          'frequency': frequency.dbValue,
          'due_day': dueDay,
          'start_date': normalizedStart,
          'created_at': now,
          'updated_at': now,
        };
        await txn.insert('zn_dues_plans', row);
        await _audit(
          txn,
          entity: 'dues_plan',
          entityId: newId,
          action: 'insert',
          newMap: row,
        );
        return newId;
      }
      final old = await _single(txn, 'zn_dues_plans', id);
      if (old == null) throw StateError('Rencana iuran tidak ditemukan');
      final updated = <String, Object?>{
        'amount': amount,
        'frequency': frequency.dbValue,
        'due_day': dueDay,
        'start_date': normalizedStart,
        'updated_at': now,
      };
      await txn.update(
        'zn_dues_plans',
        updated,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(
        txn,
        entity: 'dues_plan',
        entityId: id,
        action: 'update',
        oldMap: old,
        newMap: {...old, ...updated},
      );

      // A schedule change (frequency / due day / start date) invalidates the
      // unpaid part of the old schedule; periods that already have payments
      // are kept. The next generatePeriods call rebuilds the new schedule.
      final scheduleChanged =
          old['frequency'] != frequency.dbValue ||
          (old['due_day'] as num).toInt() != dueDay ||
          old['start_date'] != normalizedStart;
      if (scheduleChanged) {
        final replaced = await _replaceUnpaidPeriods(txn, planId: id, now: now);
        if (replaced > 0) {
          await _audit(
            txn,
            entity: 'periods',
            entityId: id,
            action: 'delete',
            newMap: {'reason': 'schedule_change', 'count': replaced},
          );
        }
      }
      return id;
    });
  }

  Future<List<DuesPlan>> getDuesPlans(String groupId) async {
    final db = await _db;
    final rows = await db.query(
      'zn_dues_plans',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DuesPlan.fromMap).toList();
  }

  // ── Periods & charges ─────────────────────────────────────────────────────

  /// Idempotently generates every period due up to [upTo] (default: today)
  /// for all active dues plans of the group, then creates charges for active
  /// members and consumes any member credits. Members are only charged for
  /// periods that end on/after their join date.
  ///
  /// Returns the number of newly created (or reactivated) periods.
  Future<int> generatePeriods({required String groupId, DateTime? upTo}) async {
    final db = await _db;
    final target = dateOnly(upTo ?? DateTime.now());
    return db.transaction((txn) async {
      final planRows = await txn.query(
        'zn_dues_plans',
        where: 'group_id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
      );
      if (planRows.isEmpty) return 0;

      final memberRows = await txn.query(
        'zn_members',
        where: 'group_id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
      );
      final members = <({String id, DateTime joinedAt})>[
        for (final row in memberRows)
          if (row['status'] == MemberStatus.active.dbValue)
            (
              id: row['id'] as String,
              joinedAt: dateOnly(dateFromStr(row['joined_at'] as String)),
            ),
      ];
      final creditMemberIds = [
        for (final row in memberRows) row['id'] as String,
      ];

      final planIds = [for (final row in planRows) row['id'] as String];
      final planPlaceholders = List.filled(planIds.length, '?').join(', ');
      final periodRows = await txn.query(
        'zn_periods',
        where: 'dues_plan_id IN ($planPlaceholders)',
        whereArgs: planIds,
      );
      final periodByKey = <String, Map<String, Object?>>{
        for (final row in periodRows)
          '${row['dues_plan_id']}|${row['start_date']}': row,
      };
      final chargeByKey = <String, Map<String, Object?>>{};
      if (periodRows.isNotEmpty) {
        final periodIds = [for (final row in periodRows) row['id'] as String];
        final periodPlaceholders = List.filled(
          periodIds.length,
          '?',
        ).join(', ');
        final chargeRows = await txn.query(
          'zn_charges',
          columns: ['id', 'period_id', 'member_id', 'deleted_at'],
          where: 'period_id IN ($periodPlaceholders)',
          whereArgs: periodIds,
        );
        for (final row in chargeRows) {
          chargeByKey['${row['period_id']}|${row['member_id']}'] = row;
        }
      }

      final now = nowIso();
      var createdPeriods = 0;
      for (final planRow in planRows) {
        final plan = DuesPlan.fromMap(planRow);
        final drafts = planPeriods(
          frequency: plan.frequency,
          dueDay: plan.dueDay,
          startDate: dateFromStr(plan.startDate),
          upTo: target,
          amount: plan.amount,
        );
        for (final draft in drafts) {
          final key = '${plan.id}|${dateToStr(draft.startDate)}';
          final existingPeriod = periodByKey[key];
          final String periodId;
          if (existingPeriod != null) {
            if (existingPeriod['deleted_at'] == null) continue;
            // Reactivate a period that was soft-deleted by a schedule change
            // (the unique index keeps deleted periods in place).
            periodId = existingPeriod['id'] as String;
            await txn.update(
              'zn_periods',
              {
                'label': draft.label,
                'end_date': dateToStr(draft.endDate),
                'due_date': dateToStr(draft.dueDate),
                'amount_snapshot': draft.amountSnapshot,
                'deleted_at': null,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [periodId],
            );
          } else {
            periodId = _newId();
            await txn.insert('zn_periods', {
              'id': periodId,
              'group_id': groupId,
              'dues_plan_id': plan.id,
              'label': draft.label,
              'start_date': dateToStr(draft.startDate),
              'end_date': dateToStr(draft.endDate),
              'due_date': dateToStr(draft.dueDate),
              'amount_snapshot': draft.amountSnapshot,
              'created_at': now,
              'updated_at': now,
            });
          }
          createdPeriods++;

          for (final member in members) {
            // B1: periods that ended before the member joined are not charged.
            if (draft.endDate.isBefore(member.joinedAt)) continue;
            final chargeKey = '$periodId|${member.id}';
            final existingCharge = chargeByKey[chargeKey];
            if (existingCharge != null) {
              if (existingCharge['deleted_at'] == null) continue;
              await txn.update(
                'zn_charges',
                {
                  'amount_due': draft.amountSnapshot,
                  'deleted_at': null,
                  'updated_at': now,
                },
                where: 'id = ?',
                whereArgs: [existingCharge['id']],
              );
            } else {
              await txn.insert('zn_charges', {
                'id': _newId(),
                'member_id': member.id,
                'period_id': periodId,
                'amount_due': draft.amountSnapshot,
                'waived': 0,
                'created_at': now,
                'updated_at': now,
              });
            }
          }
        }
      }

      if (createdPeriods > 0) {
        for (final memberId in creditMemberIds) {
          await _consumeCredits(txn, memberId: memberId, groupId: groupId);
        }
      }
      return createdPeriods;
    });
  }

  Future<List<Period>> getPeriods(String groupId) async {
    final db = await _db;
    final rows = await db.query(
      'zn_periods',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'start_date ASC',
    );
    return rows.map(Period.fromMap).toList();
  }

  Future<Period?> getCurrentPeriod(String groupId, {DateTime? asOf}) async {
    final db = await _db;
    final day = dateToStr(dateOnly(asOf ?? DateTime.now()));
    final rows = await db.query(
      'zn_periods',
      where: 'group_id = ? AND deleted_at IS NULL AND start_date <= ?',
      whereArgs: [groupId, day],
      orderBy: 'start_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Period.fromMap(rows.first);
  }

  Future<List<PeriodMemberRow>> getPeriodRows(String periodId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT c.id AS charge_id,
             c.amount_due,
             c.waived,
             p.due_date,
             m.id AS member_id,
             m.name AS member_name,
             COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
      FROM zn_charges c
      JOIN zn_members m ON m.id = c.member_id
      JOIN zn_periods p ON p.id = c.period_id
      LEFT JOIN zn_allocations a ON a.charge_id = c.id
      LEFT JOIN zn_transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
      WHERE c.period_id = ? AND c.deleted_at IS NULL AND m.deleted_at IS NULL
      GROUP BY c.id
      ORDER BY m.name COLLATE NOCASE ASC
    ''',
      [periodId],
    );
    return rows
        .map(
          (row) => PeriodMemberRow(
            chargeId: row['charge_id'] as String,
            memberId: row['member_id'] as String,
            memberName: row['member_name'] as String,
            amountDue: (row['amount_due'] as num).toInt(),
            paid: ((row['paid'] as num?) ?? 0).toInt(),
            waived: ((row['waived'] as num?)?.toInt() ?? 0) == 1,
            dueDate: dateFromStr(row['due_date'] as String),
          ),
        )
        .toList();
  }

  Future<void> setChargeWaived(String chargeId, {required bool waived}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'zn_charges', chargeId);
      if (old == null) throw StateError('Tagihan tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'waived': waived ? 1 : 0,
        'updated_at': now,
      };
      await txn.update(
        'zn_charges',
        updated,
        where: 'id = ?',
        whereArgs: [chargeId],
      );
      if (!waived) {
        final memberId = old['member_id'] as String?;
        if (memberId != null) {
          final mrows = await txn.query(
            'zn_members',
            columns: ['group_id'],
            where: 'id = ?',
            whereArgs: [memberId],
            limit: 1,
          );
          if (mrows.isNotEmpty) {
            final groupId = mrows.first['group_id'] as String;
            await _consumeCredits(txn, memberId: memberId, groupId: groupId);
          }
        }
      }
      await _audit(
        txn,
        entity: 'charge',
        entityId: chargeId,
        action: 'update',
        oldMap: old,
        newMap: {...old, ...updated},
      );
    });
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// Records a dues payment and FIFO-allocates it to the member's unpaid
  /// charges. Unallocated remainder becomes a member credit.
  ///
  /// Pass [idempotencyKey] from the UI tap gesture to make double taps safe:
  /// a repeated call with the same key returns the original transaction id.
  Future<String> recordDuesPayment({
    required String groupId,
    required String memberId,
    required int amount,
    required String date,
    String? note,
    String? idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Nominal harus lebih dari 0');
    }
    final db = await _db;
    return db.transaction((txn) async {
      if (idempotencyKey != null) {
        final existing = await txn.query(
          'zn_transactions',
          columns: ['id'],
          where: 'client_ref = ?',
          whereArgs: [idempotencyKey],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.first['id'] as String;
      }

      final id = _newId();
      final now = nowIso();
      final row = <String, Object?>{
        'id': id,
        'group_id': groupId,
        'member_id': memberId,
        'type': TxType.dues.dbValue,
        'amount': amount,
        'category': null,
        'note': note,
        'date': date,
        'is_deleted': 0,
        'client_ref': idempotencyKey,
        'created_at': now,
        'updated_at': now,
      };
      await txn.insert('zn_transactions', row);
      await _allocateForMember(
        txn,
        transactionId: id,
        memberId: memberId,
        groupId: groupId,
        amount: amount,
      );
      await _audit(
        txn,
        entity: 'transaction',
        entityId: id,
        action: 'insert',
        newMap: row,
      );
      return id;
    });
  }

  /// Records a non-dues transaction (other income or expense).
  ///
  /// Pass [idempotencyKey] from the UI tap gesture to make double taps safe:
  /// a repeated call with the same key returns the original transaction id.
  Future<String> recordTransaction({
    required String groupId,
    required TxType type,
    required int amount,
    String? category,
    String? note,
    required String date,
    String? idempotencyKey,
  }) async {
    if (type == TxType.dues) {
      throw ArgumentError('Gunakan recordDuesPayment untuk transaksi iuran');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Nominal harus lebih dari 0');
    }
    final db = await _db;
    return db.transaction((txn) async {
      if (idempotencyKey != null) {
        final existing = await txn.query(
          'zn_transactions',
          columns: ['id'],
          where: 'client_ref = ?',
          whereArgs: [idempotencyKey],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.first['id'] as String;
      }

      final id = _newId();
      final now = nowIso();
      final row = <String, Object?>{
        'id': id,
        'group_id': groupId,
        'member_id': null,
        'type': type.dbValue,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date,
        'is_deleted': 0,
        'client_ref': idempotencyKey,
        'created_at': now,
        'updated_at': now,
      };
      await txn.insert('zn_transactions', row);
      await _audit(
        txn,
        entity: 'transaction',
        entityId: id,
        action: 'insert',
        newMap: row,
      );
      return id;
    });
  }

  /// Edit-in-place: the same row is updated, old allocations and credits are
  /// removed and re-allocated FIFO inside one transaction. This is the only
  /// correction mechanism (no void + replace).
  Future<void> editTransaction({
    required String id,
    int? amount,
    String? date,
    String? note,
    String? category,
    String? memberId,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'zn_transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan');
      final old = GroupTransaction.fromMap(rows.first);
      if (old.isDeleted) throw StateError('Transaksi sudah dihapus');

      final newAmount = amount ?? old.amount;
      if (newAmount <= 0) {
        throw ArgumentError.value(
          newAmount,
          'amount',
          'Nominal harus lebih dari 0',
        );
      }
      final newMemberId = old.type == TxType.dues
          ? (memberId ?? old.memberId)
          : old.memberId;

      final now = nowIso();
      final updated = <String, Object?>{
        'amount': newAmount,
        'date': date ?? old.date,
        'note': note ?? old.note,
        'category': category ?? old.category,
        'member_id': newMemberId,
        'updated_at': now,
      };
      await txn.update(
        'zn_transactions',
        updated,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (old.type == TxType.dues) {
        await txn.delete(
          'zn_allocations',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'zn_member_credits',
          where: 'source_transaction_id = ?',
          whereArgs: [id],
        );
        if (newMemberId != null) {
          await _allocateForMember(
            txn,
            transactionId: id,
            memberId: newMemberId,
            groupId: old.groupId,
            amount: newAmount,
          );
        }
      }

      await _audit(
        txn,
        entity: 'transaction',
        entityId: id,
        action: 'update',
        oldMap: old.toMap(),
        newMap: {...old.toMap(), ...updated},
      );
    });
  }

  /// Soft-deletes a transaction and removes its allocations and credits in
  /// the same database transaction, so derived statuses instantly go back to
  /// unpaid.
  Future<void> deleteTransaction(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'zn_transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan');
      final old = GroupTransaction.fromMap(rows.first);
      if (old.isDeleted) return;

      final now = nowIso();
      await txn.update(
        'zn_transactions',
        {'is_deleted': 1, 'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      final memberId = old.memberId;
      await txn.delete(
        'zn_allocations',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'zn_member_credits',
        where: 'source_transaction_id = ?',
        whereArgs: [id],
      );
      if (memberId != null && old.type == TxType.dues) {
        final mrows = await txn.query(
          'zn_members',
          columns: ['group_id'],
          where: 'id = ?',
          whereArgs: [memberId],
          limit: 1,
        );
        if (mrows.isNotEmpty) {
          await _consumeCredits(
            txn,
            memberId: memberId,
            groupId: mrows.first['group_id'] as String,
          );
        }
      }
      await _audit(
        txn,
        entity: 'transaction',
        entityId: id,
        action: 'delete',
        oldMap: old.toMap(),
      );
    });
  }

  Future<List<GroupTransaction>> getTransactions(
    String groupId, {
    TxType? type,
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    final where = StringBuffer('group_id = ?');
    final args = <Object?>[groupId];
    if (!includeDeleted) where.write(' AND is_deleted = 0');
    if (type != null) {
      where.write(' AND type = ?');
      args.add(type.dbValue);
    }
    final rows = await db.query(
      'zn_transactions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'date DESC, created_at DESC, rowid DESC',
    );
    return rows.map(GroupTransaction.fromMap).toList();
  }

  Future<List<Allocation>> getAllocations(String transactionId) async {
    final db = await _db;
    final rows = await db.query(
      'zn_allocations',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Allocation.fromMap).toList();
  }

  /// Allocations joined with the label of the period they pay into.
  Future<List<AllocationDetail>> getAllocationDetails(
    String transactionId,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT a.id, a.transaction_id, a.charge_id, a.amount_allocated,
             a.created_at, p.label AS period_label
      FROM zn_allocations a
      JOIN zn_charges c ON c.id = a.charge_id
      JOIN zn_periods p ON p.id = c.period_id
      WHERE a.transaction_id = ?
      ORDER BY a.created_at ASC
    ''',
      [transactionId],
    );
    return rows.map(AllocationDetail.fromMap).toList();
  }

  Future<List<MemberCredit>> getMemberCredits(String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'zn_member_credits',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'created_at ASC',
    );
    return rows.map(MemberCredit.fromMap).toList();
  }

  Future<List<AuditEntry>> getAuditLog({
    String? entity,
    String? entityId,
    int limit = 100,
  }) async {
    final db = await _db;
    final where = StringBuffer('1 = 1');
    final args = <Object?>[];
    if (entity != null) {
      where.write(' AND entity = ?');
      args.add(entity);
    }
    if (entityId != null) {
      where.write(' AND entity_id = ?');
      args.add(entityId);
    }
    final rows = await db.query(
      'zn_audit_log',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(AuditEntry.fromMap).toList();
  }

  // ── Aggregates ────────────────────────────────────────────────────────────

  /// Balance is always derived: total income minus total expense over
  /// non-deleted transactions. Allocations never affect the balance.
  Future<GroupSummary> getGroupSummary({
    required String groupId,
    DateTime? asOf,
  }) async {
    final db = await _db;
    final day = dateToStr(dateOnly(asOf ?? DateTime.now()));

    final balanceRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN type = 'expense' THEN -amount ELSE amount END), 0) AS balance
      FROM zn_transactions
      WHERE group_id = ? AND is_deleted = 0
    ''',
      [groupId],
    );
    final balance = ((balanceRows.first['balance'] as num?) ?? 0).toInt();

    final overdueRows = await db.rawQuery(
      '''
      SELECT sub.member_id,
             COUNT(sub.id) AS unpaid_count,
             SUM(sub.amount_due - sub.paid) AS total_overdue
      FROM (
        SELECT c.id,
               c.member_id,
               c.amount_due,
               COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
        FROM zn_charges c
        JOIN zn_periods p ON p.id = c.period_id
        LEFT JOIN zn_allocations a ON a.charge_id = c.id
        LEFT JOIN zn_transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
        WHERE c.deleted_at IS NULL
          AND c.waived = 0
          AND p.deleted_at IS NULL
          AND p.group_id = ?
          AND p.due_date < ?
        GROUP BY c.id
      ) sub
      JOIN zn_members m ON m.id = sub.member_id AND m.deleted_at IS NULL
      WHERE sub.paid < sub.amount_due
      GROUP BY sub.member_id
    ''',
      [groupId, day],
    );

    var overdue = 0;
    for (final r in overdueRows) {
      overdue += ((r['total_overdue'] as num?) ?? 0).toInt();
    }
    final overdueMemberCount = overdueRows.length;

    final currentPeriod = await getCurrentPeriod(groupId, asOf: asOf);
    if (currentPeriod == null) {
      return GroupSummary(
        balance: balance,
        overdueTotal: overdue,
        overdueMemberCount: overdueMemberCount,
      );
    }

    final rows = await getPeriodRows(currentPeriod.id);
    final counted = rows.where((row) => !row.waived).toList();
    final paidCount = counted
        .where((row) => row.status == ChargeStatus.paid)
        .length;
    return GroupSummary(
      balance: balance,
      overdueTotal: overdue,
      overdueMemberCount: overdueMemberCount,
      currentPeriodLabel: currentPeriod.label,
      currentPeriodPaidCount: paidCount,
      currentPeriodTotalCount: counted.length,
    );
  }

  /// Returns the breakdown of overdue members with unpaid period count and total owed.
  Future<List<MemberOverdueSummary>> getOverdueMembers({
    required String groupId,
    DateTime? asOf,
  }) async {
    final db = await _db;
    final day = dateToStr(dateOnly(asOf ?? DateTime.now()));

    final rows = await db.rawQuery(
      '''
      SELECT m.id AS member_id,
             m.name AS member_name,
             COUNT(sub.charge_id) AS unpaid_count,
             SUM(sub.remaining) AS total_overdue,
             MIN(sub.due_date) AS oldest_due_date
      FROM (
        SELECT c.id AS charge_id,
               c.member_id,
               p.due_date,
               (c.amount_due - COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0)) AS remaining
        FROM zn_charges c
        JOIN zn_periods p ON p.id = c.period_id
        LEFT JOIN zn_allocations a ON a.charge_id = c.id
        LEFT JOIN zn_transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
        WHERE c.deleted_at IS NULL
          AND c.waived = 0
          AND p.deleted_at IS NULL
          AND p.group_id = ?
          AND p.due_date < ?
        GROUP BY c.id
        HAVING remaining > 0
      ) sub
      JOIN zn_members m ON m.id = sub.member_id
      WHERE m.deleted_at IS NULL
      GROUP BY m.id
      ORDER BY total_overdue DESC, unpaid_count DESC
    ''',
      [groupId, day],
    );

    return rows
        .map(
          (r) => MemberOverdueSummary(
            memberId: r['member_id'] as String,
            memberName: r['member_name'] as String,
            unpaidPeriodsCount: ((r['unpaid_count'] as num?) ?? 0).toInt(),
            totalOverdueAmount: ((r['total_overdue'] as num?) ?? 0).toInt(),
            oldestDueDate: dateFromStr(r['oldest_due_date'] as String),
          ),
        )
        .toList();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, Object?>?> _single(
    DatabaseExecutor txn,
    String table,
    String id,
  ) async {
    final rows = await txn.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _audit(
    DatabaseExecutor txn, {
    required String entity,
    required String entityId,
    required String action,
    Map<String, Object?>? oldMap,
    Map<String, Object?>? newMap,
  }) async {
    await txn.insert('zn_audit_log', {
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'old_json': oldMap == null ? null : jsonEncode(oldMap),
      'new_json': newMap == null ? null : jsonEncode(newMap),
      'created_at': nowIso(),
    });
  }

  /// Soft-deletes every active period of [planId] that has no allocation at
  /// all (nothing paid), together with its charges. Used when the dues
  /// schedule changes: paid history is preserved, unpaid periods get rebuilt
  /// by the next [generatePeriods] call.
  Future<int> _replaceUnpaidPeriods(
    DatabaseExecutor txn, {
    required String planId,
    required String now,
  }) async {
    const paidPeriods = '''
      SELECT DISTINCT c.period_id FROM zn_charges c
      JOIN zn_allocations a ON a.charge_id = c.id
    ''';
    await txn.rawUpdate(
      '''
      UPDATE zn_charges SET deleted_at = ?, updated_at = ?
      WHERE deleted_at IS NULL AND period_id IN (
        SELECT id FROM zn_periods
        WHERE dues_plan_id = ? AND deleted_at IS NULL
          AND id NOT IN ($paidPeriods)
      )
    ''',
      [now, now, planId],
    );
    final deletedPeriods = await txn.rawUpdate(
      '''
      UPDATE zn_periods SET deleted_at = ?, updated_at = ?
      WHERE dues_plan_id = ? AND deleted_at IS NULL
        AND id NOT IN ($paidPeriods)
    ''',
      [now, now, planId],
    );
    return deletedPeriods;
  }

  Future<List<Map<String, Object?>>> _unpaidCharges(
    DatabaseExecutor txn, {
    required String memberId,
    required String groupId,
  }) {
    return txn.rawQuery(
      '''
      SELECT c.id AS charge_id,
             c.amount_due,
             p.due_date,
             COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
      FROM zn_charges c
      JOIN zn_periods p ON p.id = c.period_id
      LEFT JOIN zn_allocations a ON a.charge_id = c.id
      LEFT JOIN zn_transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
      WHERE c.member_id = ?
        AND c.deleted_at IS NULL
        AND c.waived = 0
        AND p.deleted_at IS NULL
        AND p.group_id = ?
      GROUP BY c.id
      ORDER BY p.due_date ASC, c.id ASC
    ''',
      [memberId, groupId],
    );
  }

  Future<void> _allocateForMember(
    DatabaseExecutor txn, {
    required String transactionId,
    required String memberId,
    required String groupId,
    required int amount,
  }) async {
    final rows = await _unpaidCharges(
      txn,
      memberId: memberId,
      groupId: groupId,
    );
    final debts = <DebtItem>[];
    for (final row in rows) {
      final due = (row['amount_due'] as num).toInt();
      final paid = ((row['paid'] as num?) ?? 0).toInt();
      final remaining = due - paid;
      if (remaining > 0) {
        debts.add(
          DebtItem(
            chargeId: row['charge_id'] as String,
            remainingDue: remaining,
            dueDate: dateFromStr(row['due_date'] as String),
          ),
        );
      }
    }

    final result = allocateFifo(amount: amount, debts: debts);
    final now = nowIso();
    for (final draft in result.allocations) {
      await txn.insert('zn_allocations', {
        'id': _newId(),
        'transaction_id': transactionId,
        'charge_id': draft.chargeId,
        'amount_allocated': draft.amount,
        'created_at': now,
      });
    }
    if (result.leftover > 0) {
      await txn.insert('zn_member_credits', {
        'id': _newId(),
        'member_id': memberId,
        'source_transaction_id': transactionId,
        'amount_remaining': result.leftover,
        'created_at': now,
      });
    }
  }

  /// Consumes member credits (from overpayments) against the member's oldest
  /// unpaid charges. Each consumption is recorded as an allocation row whose
  /// `transaction_id` is the credit's source transaction, so editing or
  /// deleting that transaction correctly reverts everything.
  Future<void> _consumeCredits(
    DatabaseExecutor txn, {
    required String memberId,
    required String groupId,
  }) async {
    final credits = await txn.query(
      'zn_member_credits',
      where: 'member_id = ? AND amount_remaining > 0',
      whereArgs: [memberId],
      orderBy: 'created_at ASC',
    );
    if (credits.isEmpty) return;

    final rows = await _unpaidCharges(
      txn,
      memberId: memberId,
      groupId: groupId,
    );
    final remaining = <String, int>{};
    final dueDates = <String, DateTime>{};
    for (final row in rows) {
      final due = (row['amount_due'] as num).toInt();
      final paid = ((row['paid'] as num?) ?? 0).toInt();
      final left = due - paid;
      if (left > 0) {
        final chargeId = row['charge_id'] as String;
        remaining[chargeId] = left;
        dueDates[chargeId] = dateFromStr(row['due_date'] as String);
      }
    }
    final orderedCharges = remaining.keys.toList()
      ..sort((a, b) {
        final byDate = dueDates[a]!.compareTo(dueDates[b]!);
        if (byDate != 0) return byDate;
        return a.compareTo(b);
      });

    for (final creditRow in credits) {
      var creditLeft = (creditRow['amount_remaining'] as num).toInt();
      if (creditLeft <= 0) continue;
      for (final chargeId in orderedCharges) {
        if (creditLeft <= 0) break;
        final chargeLeft = remaining[chargeId] ?? 0;
        if (chargeLeft <= 0) continue;
        final take = math.min(creditLeft, chargeLeft);
        final existing = await txn.query(
          'zn_allocations',
          where: 'transaction_id = ? AND charge_id = ?',
          whereArgs: [creditRow['source_transaction_id'], chargeId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final oldAmt = (existing.first['amount_allocated'] as num).toInt();
          await txn.update(
            'zn_allocations',
            {'amount_allocated': oldAmt + take},
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          await txn.insert('zn_allocations', {
            'id': _newId(),
            'transaction_id': creditRow['source_transaction_id'],
            'charge_id': chargeId,
            'amount_allocated': take,
            'created_at': nowIso(),
          });
        }
        creditLeft -= take;
        remaining[chargeId] = chargeLeft - take;
      }
      if (creditLeft <= 0) {
        await txn.delete(
          'zn_member_credits',
          where: 'id = ?',
          whereArgs: [creditRow['id']],
        );
      } else {
        await txn.update(
          'zn_member_credits',
          {'amount_remaining': creditLeft},
          where: 'id = ?',
          whereArgs: [creditRow['id']],
        );
      }
    }
  }
}
