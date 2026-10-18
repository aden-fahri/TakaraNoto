import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finflow_flutter/zainnoto/logic/dues_status.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

typedef DuesTestContext = ({
  Database db,
  ZainNotoRepository repo,
  String groupId,
  String planId,
});

Future<DuesTestContext> seedMonthly({
  String startDate = '2026-01-01',
  int amount = 100000,
  int dueDay = 10,
}) async {
  final db = await openTestDatabase();

  final repo = ZainNotoRepository();
  final groupId = await repo.createGroup(name: 'Kas RT');
  final planId = await repo.upsertDuesPlan(
    groupId: groupId,
    amount: amount,
    frequency: DuesFrequency.monthly,
    dueDay: dueDay,
    startDate: startDate,
  );
  return (db: db, repo: repo, groupId: groupId, planId: planId);
}

Future<int> activeChargeCount(DuesTestContext ctx, String memberId) async {
  final rows = await ctx.db.query(
    'zn_charges',
    where: 'member_id = ? AND deleted_at IS NULL',
    whereArgs: [memberId],
  );
  return rows.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('B1: anggota baru ditagih mulai periode bergabung, bukan periode lampau',
      () async {
    final ctx = await seedMonthly();
    final oldMember = await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Lama',
      joinedAt: '2025-12-01',
    );
    final newMember = await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Baru',
      joinedAt: '2026-02-15',
    );

    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 3, 31),
    );

    final periods = await ctx.repo.getPeriods(ctx.groupId);
    expect(periods.map((p) => p.startDate),
        ['2026-01-01', '2026-02-01', '2026-03-01']);
    expect(await activeChargeCount(ctx, oldMember), 3);
    expect(await activeChargeCount(ctx, newMember), 2);

    final db = ctx.db;
    final rows = await db.query(
      'zn_charges',
      where: 'member_id = ? AND deleted_at IS NULL',
      whereArgs: [newMember],
      orderBy: 'created_at ASC',
    );
    final periodsById = {for (final p in periods) p.id: p};
    final chargedStarts = [
      for (final row in rows) periodsById[row['period_id']]!.startDate,
    ]..sort();
    expect(chargedStarts, ['2026-02-01', '2026-03-01']);
  });

  test('B1: backfill addMember tidak membuat tagihan untuk periode lampau',
      () async {
    final ctx = await seedMonthly();
    await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Lama',
      joinedAt: '2025-12-01',
    );
    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 3, 31),
    );

    final newMember = await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Baru',
      joinedAt: '2026-03-20',
    );

    expect(await activeChargeCount(ctx, newMember), 1);
  });

  test('B2: ubah frekuensi mengganti periode belum lunas, periode berbayar tetap',
      () async {
    final ctx = await seedMonthly();
    final member = await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Alice',
      joinedAt: '2026-01-01',
    );
    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 3, 31),
    );
    expect((await ctx.repo.getPeriods(ctx.groupId)).length, 3);

    await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: member,
      amount: 100000,
      date: '2026-01-05',
    );

    await ctx.repo.upsertDuesPlan(
      id: ctx.planId,
      groupId: ctx.groupId,
      amount: 100000,
      frequency: DuesFrequency.weekly,
      dueDay: 7,
      startDate: '2026-01-01',
    );

    final kept = await ctx.repo.getPeriods(ctx.groupId);
    expect(kept.length, 1);
    expect(kept.single.startDate, '2026-01-01');
    final keptRows = await ctx.repo.getPeriodRows(kept.single.id);
    expect(keptRows.single.status, ChargeStatus.paid);

    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 3, 31),
    );

    final active = await ctx.repo.getPeriods(ctx.groupId);
    expect(active.length, 13);
    expect(await activeChargeCount(ctx, member), 13);

    final db = ctx.db;
    final softDeleted = await db.query(
      'zn_periods',
      where: 'deleted_at IS NOT NULL',
    );
    expect(softDeleted.length, 2);
  });

  test('B3: anggota terhapus tidak dihitung di rekap dan checklist', () async {
    final ctx = await seedMonthly();
    await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Lama',
      joinedAt: '2025-12-01',
    );
    final leaving = await ctx.repo.addMember(
      groupId: ctx.groupId,
      name: 'Keluar',
      joinedAt: '2025-12-01',
    );
    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 2, 15),
    );

    final asOf = DateTime(2026, 3, 1);
    var summary =
        await ctx.repo.getGroupSummary(groupId: ctx.groupId, asOf: asOf);
    expect(summary.overdueMemberCount, 2);
    expect(summary.overdueTotal, 400000);

    await ctx.repo.softDeleteMember(leaving);

    summary =
        await ctx.repo.getGroupSummary(groupId: ctx.groupId, asOf: asOf);
    expect(summary.overdueMemberCount, 1);
    expect(summary.overdueTotal, 200000);
    expect(summary.currentPeriodTotalCount, 1);

    final current =
        await ctx.repo.getCurrentPeriod(ctx.groupId, asOf: asOf);
    final rows = await ctx.repo.getPeriodRows(current!.id);
    expect(rows.map((r) => r.memberName), ['Lama']);
  });

  test('B4: recordTransaction idempoten dengan kunci yang sama', () async {
    final ctx = await seedMonthly();
    final first = await ctx.repo.recordTransaction(
      groupId: ctx.groupId,
      type: TxType.expense,
      amount: 25000,
      note: 'Konsumsi',
      date: '2026-01-10',
      idempotencyKey: 'tap-1',
    );
    final second = await ctx.repo.recordTransaction(
      groupId: ctx.groupId,
      type: TxType.expense,
      amount: 25000,
      note: 'Konsumsi',
      date: '2026-01-10',
      idempotencyKey: 'tap-1',
    );
    expect(second, first);

    final db = ctx.db;
    final rows = await db.query('zn_transactions');
    expect(rows.length, 1);
  });

  test('B5: hanya satu rencana aktif dan input tervalidasi', () async {
    final ctx = await seedMonthly();

    await expectLater(
      ctx.repo.upsertDuesPlan(
        groupId: ctx.groupId,
        amount: 50000,
        frequency: DuesFrequency.monthly,
        dueDay: 10,
        startDate: '2026-02-01',
      ),
      throwsStateError,
    );

    await expectLater(
      ctx.repo.upsertDuesPlan(
        id: ctx.planId,
        groupId: ctx.groupId,
        amount: 50000,
        frequency: DuesFrequency.monthly,
        dueDay: 10,
        startDate: 'bukan-tanggal',
      ),
      throwsArgumentError,
    );

    await expectLater(
      ctx.repo.upsertDuesPlan(
        id: ctx.planId,
        groupId: ctx.groupId,
        amount: 50000,
        frequency: DuesFrequency.weekly,
        dueDay: 8,
        startDate: '2026-02-01',
      ),
      throwsArgumentError,
    );

    final plans = await ctx.repo.getDuesPlans(ctx.groupId);
    expect(plans.length, 1);
    expect(plans.single.startDate, '2026-01-01');
  });
}
