import 'dart:convert';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/zainnoto_database.dart';
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
/// Every insert/update/delete of user data is mirrored into `audit_log`.
class ZainNotoRepository {
  ZainNotoRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final ZainNotoDatabase _database;
  final Uuid _uuid;

  Future<Database> get _db => _database.open();

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
      await txn.insert('groups', row);
      await _audit(txn,
          entity: 'group', entityId: id, action: 'insert', newMap: row);
    });
    return id;
  }

  Future<List<Group>> getGroups() async {
    final db = await _db;
    final rows = await db.query(
      'groups',
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
      final old = await _single(txn, 'groups', id);
      if (old == null) throw StateError('Grup tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'name': name ?? old['name'],
        'description': description ?? old['description'],
        'icon_index': iconIndex ?? old['icon_index'],
        'color_hex': colorHex ?? old['color_hex'],
        'updated_at': now,
      };
      await txn.update('groups', updated, where: 'id = ?', whereArgs: [id]);
      await _audit(txn,
          entity: 'group',
          entityId: id,
          action: 'update',
          oldMap: old,
          newMap: {...old, ...updated});
    });
  }

  Future<void> softDeleteGroup(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'groups', id);
      if (old == null) return;
      final now = nowIso();
      await txn.update(
        'groups',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(txn,
          entity: 'group', entityId: id, action: 'delete', oldMap: old);
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
      await txn.insert('members', row);
      await _audit(txn,
          entity: 'member', entityId: id, action: 'insert', newMap: row);
    });
    return id;
  }

  Future<List<Member>> getMembers(
    String groupId, {
    bool includeInactive = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'members',
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
      final old = await _single(txn, 'members', id);
      if (old == null) throw StateError('Anggota tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'name': name ?? old['name'],
        'phone_number': phoneNumber ?? old['phone_number'],
        'status': status?.dbValue ?? old['status'],
        'updated_at': now,
      };
      await txn.update('members', updated, where: 'id = ?', whereArgs: [id]);
      await _audit(txn,
          entity: 'member',
          entityId: id,
          action: 'update',
          oldMap: old,
          newMap: {...old, ...updated});
    });
  }

  Future<void> softDeleteMember(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'members', id);
      if (old == null) return;
      final now = nowIso();
      await txn.update(
        'members',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _audit(txn,
          entity: 'member', entityId: id, action: 'delete', oldMap: old);
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
      throw ArgumentError.value(amount, 'amount', 'Nominal tidak boleh negatif');
    }
    final db = await _db;
    final now = nowIso();
    return db.transaction((txn) async {
      if (id == null) {
        final newId = _newId();
        final row = <String, Object?>{
          'id': newId,
          'group_id': groupId,
          'amount': amount,
          'frequency': frequency.dbValue,
          'due_day': dueDay,
          'start_date': startDate,
          'created_at': now,
          'updated_at': now,
        };
        await txn.insert('dues_plans', row);
        await _audit(txn,
            entity: 'dues_plan', entityId: newId, action: 'insert', newMap: row);
        return newId;
      }
      final old = await _single(txn, 'dues_plans', id);
      if (old == null) throw StateError('Rencana iuran tidak ditemukan');
      final updated = <String, Object?>{
        'amount': amount,
        'frequency': frequency.dbValue,
        'due_day': dueDay,
        'start_date': startDate,
        'updated_at': now,
      };
      await txn.update('dues_plans', updated, where: 'id = ?', whereArgs: [id]);
      await _audit(txn,
          entity: 'dues_plan',
          entityId: id,
          action: 'update',
          oldMap: old,
          newMap: {...old, ...updated});
      return id;
    });
  }

  Future<List<DuesPlan>> getDuesPlans(String groupId) async {
    final db = await _db;
    final rows = await db.query(
      'dues_plans',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DuesPlan.fromMap).toList();
  }

  // ── Periods & charges ─────────────────────────────────────────────────────

  /// Idempotently generates every period due up to [upTo] (default: today)
  /// for all active dues plans of the group, then creates charges for active
  /// members and consumes any member credits.
  ///
  /// Returns the number of newly created periods.
  Future<int> generatePeriods({required String groupId, DateTime? upTo}) async {
    final db = await _db;
    final target = dateOnly(upTo ?? DateTime.now());
    return db.transaction((txn) async {
      final planRows = await txn.query(
        'dues_plans',
        where: 'group_id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
      );
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
          final existing = await txn.query(
            'periods',
            columns: ['id'],
            where: 'dues_plan_id = ? AND start_date = ?',
            whereArgs: [plan.id, dateToStr(draft.startDate)],
            limit: 1,
          );
          if (existing.isNotEmpty) continue;

          final periodId = _newId();
          final now = nowIso();
          await txn.insert('periods', {
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

          final members = await txn.query(
            'members',
            where:
                'group_id = ? AND deleted_at IS NULL AND status = ? AND joined_at <= ?',
            whereArgs: [
              groupId,
              MemberStatus.active.dbValue,
              dateToStr(draft.endDate),
            ],
          );
          for (final member in members) {
            await txn.insert(
              'charges',
              {
                'id': _newId(),
                'member_id': member['id'],
                'period_id': periodId,
                'amount_due': draft.amountSnapshot,
                'waived': 0,
                'created_at': now,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          createdPeriods++;
        }
      }

      if (createdPeriods > 0) {
        final members = await txn.query(
          'members',
          where: 'group_id = ? AND deleted_at IS NULL',
          whereArgs: [groupId],
        );
        for (final member in members) {
          await _consumeCredits(
            txn,
            memberId: member['id'] as String,
            groupId: groupId,
          );
        }
      }
      return createdPeriods;
    });
  }

  Future<List<Period>> getPeriods(String groupId) async {
    final db = await _db;
    final rows = await db.query(
      'periods',
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
      'periods',
      where: 'group_id = ? AND deleted_at IS NULL AND start_date <= ?',
      whereArgs: [groupId, day],
      orderBy: 'start_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Period.fromMap(rows.first);
  }

  Future<List<PeriodMemberRow>> getPeriodRows(String periodId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.id AS charge_id,
             c.amount_due,
             c.waived,
             p.due_date,
             m.id AS member_id,
             m.name AS member_name,
             COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
      FROM charges c
      JOIN members m ON m.id = c.member_id
      JOIN periods p ON p.id = c.period_id
      LEFT JOIN allocations a ON a.charge_id = c.id
      LEFT JOIN transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
      WHERE c.period_id = ? AND c.deleted_at IS NULL
      GROUP BY c.id
      ORDER BY m.name COLLATE NOCASE ASC
    ''', [periodId]);
    return rows
        .map((row) => PeriodMemberRow(
              chargeId: row['charge_id'] as String,
              memberId: row['member_id'] as String,
              memberName: row['member_name'] as String,
              amountDue: (row['amount_due'] as num).toInt(),
              paid: ((row['paid'] as num?) ?? 0).toInt(),
              waived: ((row['waived'] as num?)?.toInt() ?? 0) == 1,
              dueDate: dateFromStr(row['due_date'] as String),
            ))
        .toList();
  }

  Future<void> setChargeWaived(String chargeId, {required bool waived}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final old = await _single(txn, 'charges', chargeId);
      if (old == null) throw StateError('Tagihan tidak ditemukan');
      final now = nowIso();
      final updated = <String, Object?>{
        'waived': waived ? 1 : 0,
        'updated_at': now,
      };
      await txn
          .update('charges', updated, where: 'id = ?', whereArgs: [chargeId]);
      await _audit(txn,
          entity: 'charge',
          entityId: chargeId,
          action: 'update',
          oldMap: old,
          newMap: {...old, ...updated});
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
          'transactions',
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
      await txn.insert('transactions', row);
      await _allocateForMember(
        txn,
        transactionId: id,
        memberId: memberId,
        groupId: groupId,
        amount: amount,
      );
      await _audit(txn,
          entity: 'transaction', entityId: id, action: 'insert', newMap: row);
      return id;
    });
  }

  /// Records a non-dues transaction (other income or expense).
  Future<String> recordTransaction({
    required String groupId,
    required TxType type,
    required int amount,
    String? category,
    String? note,
    required String date,
  }) async {
    if (type == TxType.dues) {
      throw ArgumentError('Gunakan recordDuesPayment untuk transaksi iuran');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Nominal harus lebih dari 0');
    }
    final db = await _db;
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
      'created_at': now,
      'updated_at': now,
    };
    await db.transaction((txn) async {
      await txn.insert('transactions', row);
      await _audit(txn,
          entity: 'transaction', entityId: id, action: 'insert', newMap: row);
    });
    return id;
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
        'transactions',
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
            newAmount, 'amount', 'Nominal harus lebih dari 0');
      }
      final newMemberId =
          old.type == TxType.dues ? (memberId ?? old.memberId) : old.memberId;

      final now = nowIso();
      final updated = <String, Object?>{
        'amount': newAmount,
        'date': date ?? old.date,
        'note': note ?? old.note,
        'category': category ?? old.category,
        'member_id': newMemberId,
        'updated_at': now,
      };
      await txn.update('transactions', updated, where: 'id = ?', whereArgs: [id]);

      if (old.type == TxType.dues) {
        await txn.delete('allocations',
            where: 'transaction_id = ?', whereArgs: [id]);
        await txn.delete('member_credits',
            where: 'source_transaction_id = ?', whereArgs: [id]);
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

      await _audit(txn,
          entity: 'transaction',
          entityId: id,
          action: 'update',
          oldMap: old.toMap(),
          newMap: {...old.toMap(), ...updated});
    });
  }

  /// Soft-deletes a transaction and removes its allocations and credits in
  /// the same database transaction, so derived statuses instantly go back to
  /// unpaid.
  Future<void> deleteTransaction(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan');
      final old = GroupTransaction.fromMap(rows.first);
      if (old.isDeleted) return;

      final now = nowIso();
      await txn.update(
        'transactions',
        {'is_deleted': 1, 'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('allocations',
          where: 'transaction_id = ?', whereArgs: [id]);
      await txn.delete('member_credits',
          where: 'source_transaction_id = ?', whereArgs: [id]);
      await _audit(txn,
          entity: 'transaction', entityId: id, action: 'delete', oldMap: old.toMap());
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
      'transactions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(GroupTransaction.fromMap).toList();
  }

  Future<List<Allocation>> getAllocations(String transactionId) async {
    final db = await _db;
    final rows = await db.query(
      'allocations',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Allocation.fromMap).toList();
  }

  Future<List<MemberCredit>> getMemberCredits(String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'member_credits',
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
      'audit_log',
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

    final balanceRows = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN type = 'expense' THEN -amount ELSE amount END), 0) AS balance
      FROM transactions
      WHERE group_id = ? AND is_deleted = 0
    ''', [groupId]);
    final balance = ((balanceRows.first['balance'] as num?) ?? 0).toInt();

    final overdueRows = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN paid < amount_due THEN amount_due - paid ELSE 0 END), 0) AS overdue
      FROM (
        SELECT c.id,
               c.amount_due,
               COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
        FROM charges c
        JOIN periods p ON p.id = c.period_id
        LEFT JOIN allocations a ON a.charge_id = c.id
        LEFT JOIN transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
        WHERE c.deleted_at IS NULL
          AND c.waived = 0
          AND p.deleted_at IS NULL
          AND p.group_id = ?
          AND p.due_date < ?
        GROUP BY c.id
      )
    ''', [groupId, day]);
    final overdue = ((overdueRows.first['overdue'] as num?) ?? 0).toInt();

    final currentPeriod = await getCurrentPeriod(groupId, asOf: asOf);
    if (currentPeriod == null) {
      return GroupSummary(balance: balance, overdueTotal: overdue);
    }

    final rows = await getPeriodRows(currentPeriod.id);
    final counted = rows.where((row) => !row.waived).toList();
    final paidCount =
        counted.where((row) => row.status == ChargeStatus.paid).length;
    return GroupSummary(
      balance: balance,
      overdueTotal: overdue,
      currentPeriodLabel: currentPeriod.label,
      currentPeriodPaidCount: paidCount,
      currentPeriodTotalCount: counted.length,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, Object?>?> _single(
    DatabaseExecutor txn,
    String table,
    String id,
  ) async {
    final rows = await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
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
    await txn.insert('audit_log', {
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'old_json': oldMap == null ? null : jsonEncode(oldMap),
      'new_json': newMap == null ? null : jsonEncode(newMap),
      'created_at': nowIso(),
    });
  }

  Future<List<Map<String, Object?>>> _unpaidCharges(
    DatabaseExecutor txn, {
    required String memberId,
    required String groupId,
  }) {
    return txn.rawQuery('''
      SELECT c.id AS charge_id,
             c.amount_due,
             p.due_date,
             COALESCE(SUM(CASE WHEN t.id IS NULL THEN 0 ELSE a.amount_allocated END), 0) AS paid
      FROM charges c
      JOIN periods p ON p.id = c.period_id
      LEFT JOIN allocations a ON a.charge_id = c.id
      LEFT JOIN transactions t ON t.id = a.transaction_id AND t.is_deleted = 0
      WHERE c.member_id = ?
        AND c.deleted_at IS NULL
        AND c.waived = 0
        AND p.deleted_at IS NULL
        AND p.group_id = ?
      GROUP BY c.id
      ORDER BY p.due_date ASC, c.id ASC
    ''', [memberId, groupId]);
  }

  Future<void> _allocateForMember(
    DatabaseExecutor txn, {
    required String transactionId,
    required String memberId,
    required String groupId,
    required int amount,
  }) async {
    final rows = await _unpaidCharges(txn, memberId: memberId, groupId: groupId);
    final debts = <DebtItem>[];
    for (final row in rows) {
      final due = (row['amount_due'] as num).toInt();
      final paid = ((row['paid'] as num?) ?? 0).toInt();
      final remaining = due - paid;
      if (remaining > 0) {
        debts.add(DebtItem(
          chargeId: row['charge_id'] as String,
          remainingDue: remaining,
          dueDate: dateFromStr(row['due_date'] as String),
        ));
      }
    }

    final result = allocateFifo(amount: amount, debts: debts);
    final now = nowIso();
    for (final draft in result.allocations) {
      await txn.insert('allocations', {
        'id': _newId(),
        'transaction_id': transactionId,
        'charge_id': draft.chargeId,
        'amount_allocated': draft.amount,
        'created_at': now,
      });
    }
    if (result.leftover > 0) {
      await txn.insert('member_credits', {
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
      'member_credits',
      where: 'member_id = ? AND amount_remaining > 0',
      whereArgs: [memberId],
      orderBy: 'created_at ASC',
    );
    if (credits.isEmpty) return;

    final rows = await _unpaidCharges(txn, memberId: memberId, groupId: groupId);
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
        await txn.insert('allocations', {
          'id': _newId(),
          'transaction_id': creditRow['source_transaction_id'],
          'charge_id': chargeId,
          'amount_allocated': take,
          'created_at': nowIso(),
        });
        creditLeft -= take;
        remaining[chargeId] = chargeLeft - take;
      }
      if (creditLeft <= 0) {
        await txn.delete('member_credits',
            where: 'id = ?', whereArgs: [creditRow['id']]);
      } else {
        await txn.update(
          'member_credits',
          {'amount_remaining': creditLeft},
          where: 'id = ?',
          whereArgs: [creditRow['id']],
        );
      }
    }
  }
}
