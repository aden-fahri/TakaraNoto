import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'helpers.dart';

const int _iters = 20;
const int _seedCount = 20;

Future<void> _runScenario(int seed, int invariantIndex) async {
  final rng = Random(seed);
  final ctx = await seedWeekly(amount: 20000, dueDay: 1, startDate: '2026-01-05');
  final repo = ctx.repo;
  final db = ctx.db;
  final groupId = ctx.groupId;

  for (var iter = 0; iter < _iters; iter++) {
    final op = rng.nextInt(7);
    try {
      switch (op) {
        case 0:
          await repo.addMember(
            groupId: groupId,
            name: 'M${rng.nextInt(1000)}',
            joinedAt: '2026-01-${(rng.nextInt(28) + 1).toString().padLeft(2, '0')}',
          );
          break;
        case 1:
          final ms = await repo.getMembers(groupId);
          if (ms.isNotEmpty) await repo.softDeleteMember(ms[rng.nextInt(ms.length)].id);
          break;
        case 2:
          final plans = await repo.getDuesPlans(groupId);
          if (plans.isNotEmpty) {
            final freq = rng.nextBool() ? DuesFrequency.weekly : DuesFrequency.monthly;
            final dueDay = freq == DuesFrequency.weekly ? (rng.nextInt(7) + 1) : (rng.nextInt(28) + 1);
            await repo.upsertDuesPlan(
              id: plans.first.id,
              groupId: groupId,
              amount: (rng.nextInt(5) + 1) * 10000,
              frequency: freq,
              dueDay: dueDay,
              startDate: '2026-01-05',
            );
          }
          break;
        case 3:
          final ms = await repo.getMembers(groupId);
          if (ms.isNotEmpty) {
            final m = ms[rng.nextInt(ms.length)];
            await repo.recordDuesPayment(
              groupId: groupId,
              memberId: m.id,
              amount: (rng.nextInt(5) + 1) * 10000,
              date: '2026-01-10',
            );
          }
          break;
        case 4:
          final txs = await db.query('zn_transactions', where: "type='dues' AND is_deleted=0");
          if (txs.isNotEmpty) {
            await repo.deleteTransaction(txs[rng.nextInt(txs.length)]['id'] as String);
          }
          break;
        case 5:
          final ch = await db.query('zn_charges', where: 'deleted_at IS NULL');
          if (ch.isNotEmpty) {
            await repo.setChargeWaived(ch[rng.nextInt(ch.length)]['id'] as String, waived: rng.nextBool());
          }
          break;
        default:
          await repo.generatePeriods(groupId: groupId, upTo: DateTime(2026, 1 + rng.nextInt(3), rng.nextInt(28) + 1));
          break;
      }
    } catch (e) {
      // ignore
    }

    // invariants
    final charges = await db.query('zn_charges', where: 'deleted_at IS NULL');

    if (invariantIndex == 0) {
      for (final c in charges) {
        final alloc = await db.rawQuery('SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE charge_id=?', [c['id']]);
        expect((alloc.first['s'] as num).toInt(), lessThanOrEqualTo(c['amount_due'] as int));
      }
    }
    if (invariantIndex == 1) {
      final txs = await db.query('zn_transactions', where: "type='dues' AND is_deleted=0");
      for (final t in txs) {
        final alloc = await db.rawQuery('SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations WHERE transaction_id=?', [t['id']]);
        final a = (alloc.first['s'] as num).toInt();
        final cred = await db.rawQuery('SELECT COALESCE(SUM(amount_remaining),0) s FROM zn_member_credits WHERE source_transaction_id=?', [t['id']]);
        final cr = (cred.first['s'] as num).toInt();
        expect(a + cr, t['amount'] as int);
      }
    }
    if (invariantIndex == 2) {
      final dup = await db.rawQuery('SELECT period_id, member_id, COUNT(*) c FROM zn_charges WHERE deleted_at IS NULL GROUP BY period_id, member_id HAVING c>1');
      expect(dup, isEmpty);
    }
    if (invariantIndex == 3) {
      final overdue = await repo.getOverdueMembers(groupId: groupId, asOf: DateTime(2026, 3, 1));
      final sumOverdue = overdue.fold<int>(0, (s, m) => s + m.totalOverdueAmount);
        var total = 0;
        for (final c in charges) {
          final member = await db.query('zn_members', where: 'id=?', whereArgs: [c['member_id']], limit: 1);
          if (member.isEmpty || member.first['deleted_at'] != null) continue;
          final period = await db.query('zn_periods', where: 'id=?', whereArgs: [c['period_id']], limit: 1);
          if (period.isEmpty || period.first['deleted_at'] != null) continue;
          final due = period.first['due_date'] as String;
          if (!(due.compareTo('2026-03-01') < 0)) continue;
          if ((c['waived'] as int) == 1) continue;
          final alloc = await db.rawQuery('SELECT COALESCE(SUM(amount_allocated),0) s FROM zn_allocations a JOIN zn_transactions t ON t.id=a.transaction_id AND t.is_deleted=0 WHERE a.charge_id=?', [c['id']]);
          final a = (alloc.first['s'] as num).toInt();
          final remaining = (c['amount_due'] as int) - a;
          if (remaining > 0) total += remaining;
        }
      expect(sumOverdue, total);
    }
    if (invariantIndex == 4) {
      final bad = await db.rawQuery('''
        SELECT COUNT(*) c FROM zn_charges c JOIN zn_periods p ON p.id=c.period_id
        WHERE c.deleted_at IS NULL AND c.waived=0 AND p.due_date < '2026-03-01'
        AND (SELECT COALESCE(SUM(a.amount_allocated),0) FROM zn_allocations a JOIN zn_transactions t ON t.id=a.transaction_id AND t.is_deleted=0 WHERE a.charge_id=c.id) < c.amount_due
        AND (SELECT COALESCE(SUM(cr.amount_remaining),0) FROM zn_member_credits cr WHERE cr.member_id=c.member_id) > 0
      ''');
      expect((bad.first['c'] as num).toInt(), 0);
    }
    if (invariantIndex == 5) {
      final badAlloc = await db.rawQuery('SELECT COUNT(*) c FROM zn_allocations a LEFT JOIN zn_transactions t ON t.id=a.transaction_id WHERE t.is_deleted=1 OR t.id IS NULL');
      expect((badAlloc.first['c'] as num).toInt(), 0);
    }
  }
}

const List<String> _invNames = [
  'alloc<=due',
  'alloc+credit=nominal',
  'one charge per member/period',
  'tunggakan=sum',
  'no credit+unpaid',
  'no alloc to deleted',
];

void main() {
  for (var i = 0; i < 6; i++) {
    test('invarian ${_invNames[i]} acak', () async {
      for (var s = 1; s <= _seedCount; s++) {
        // ignore: avoid_print
        print('SEED=$s INV=$_invNames[$i]');
        await _runScenario(s, i);
      }
    });
  }
}
