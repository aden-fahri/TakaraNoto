import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/zainnoto/logic/dues_status.dart';
import 'package:finflow_flutter/zainnoto/models/derived.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';

import 'helpers.dart';

PeriodMemberRow rowFor(List<PeriodMemberRow> rows, String memberId) =>
    rows.firstWhere((row) => row.memberId == memberId);

void main() {
  group('anti double-transaction', () {
    test('edit nominal 10.000 -> 15.000 hanya menambah 5.000', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final period = (await ctx.repo.getPeriods(ctx.groupId)).single;

      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 10000,
        date: '2026-01-05',
      );
      var summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 10000);

      await ctx.repo.editTransaction(id: txId, amount: 15000);
      summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 15000,
          reason: 'saldo harus bertambah 5.000, bukan 25.000');

      final alice =
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId);
      expect(alice.paid, 15000);
      expect(alice.status, ChargeStatus.partial);

      final allocations = await ctx.repo.getAllocations(txId);
      expect(allocations, hasLength(1));
      expect(allocations.single.amountAllocated, 15000);

      final txs = await ctx.repo.getTransactions(ctx.groupId);
      expect(txs.single.amount, 15000);
    });

    test('edit tanpa perubahan tidak mengubah saldo dan alokasi', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 10000,
        date: '2026-01-05',
        note: 'catatan',
      );

      await ctx.repo.editTransaction(
        id: txId,
        amount: 10000,
        date: '2026-01-05',
        note: 'catatan',
      );

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 10000);
      final allocations = await ctx.repo.getAllocations(txId);
      expect(allocations, hasLength(1));
      expect(
        allocations.fold<int>(0, (sum, a) => sum + a.amountAllocated),
        10000,
      );
    });

    test('edit dua kali berturut-turut sama dengan edit sekali', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final period = (await ctx.repo.getPeriods(ctx.groupId)).single;
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 10000,
        date: '2026-01-05',
      );

      await ctx.repo.editTransaction(id: txId, amount: 15000);
      await ctx.repo.editTransaction(id: txId, amount: 12000);

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 12000);
      final alice =
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId);
      expect(alice.paid, 12000);
      final allocations = await ctx.repo.getAllocations(txId);
      expect(
        allocations.fold<int>(0, (sum, a) => sum + a.amountAllocated),
        12000,
      );
    });

    test('hapus pembayaran: tagihan kembali menunggak dan saldo berkurang',
        () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final period = (await ctx.repo.getPeriods(ctx.groupId)).single;
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
      );

      var alice =
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId);
      expect(alice.status, ChargeStatus.paid);

      await ctx.repo.deleteTransaction(txId);

      alice = rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId);
      expect(alice.status, ChargeStatus.unpaid);
      expect(alice.paid, 0);

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 0);
      expect(await ctx.repo.getAllocations(txId), isEmpty);
      expect(await ctx.repo.getTransactions(ctx.groupId), isEmpty);

      final all =
          await ctx.repo.getTransactions(ctx.groupId, includeDeleted: true);
      expect(all.single.isDeleted, isTrue);

      final audit =
          await ctx.repo.getAuditLog(entity: 'transaction', entityId: txId);
      expect(audit.map((e) => e.action).toList(), contains('delete'));
    });

    test('ganti anggota: tagihan anggota lama menunggak lagi', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final period = (await ctx.repo.getPeriods(ctx.groupId)).single;
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
      );

      await ctx.repo.editTransaction(id: txId, memberId: ctx.bobId);

      final rows = await ctx.repo.getPeriodRows(period.id);
      expect(rowFor(rows, ctx.aliceId).status, ChargeStatus.unpaid);
      expect(rowFor(rows, ctx.bobId).status, ChargeStatus.paid);

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 20000);
    });

    test('dobel ketuk 1-tap: hanya satu transaksi tercipta', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));

      final first = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
        idempotencyKey: 'tap-1',
      );
      final second = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
        idempotencyKey: 'tap-1',
      );

      expect(second, first);
      expect(await ctx.repo.getTransactions(ctx.groupId), hasLength(1));
      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 20000);
    });

    test('bayar di muka 3 periode lalu edit jadi 1 periode', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 19));
      final periods = await ctx.repo.getPeriods(ctx.groupId);
      expect(periods, hasLength(3));

      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 60000,
        date: '2026-01-05',
      );
      for (final period in periods) {
        expect(
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId).status,
          ChargeStatus.paid,
        );
      }

      await ctx.repo.editTransaction(id: txId, amount: 20000);

      final statuses = <ChargeStatus>[];
      for (final period in periods) {
        statuses.add(
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId).status,
        );
      }
      expect(statuses, [
        ChargeStatus.paid,
        ChargeStatus.unpaid,
        ChargeStatus.unpaid,
      ]);

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 20000);
      expect(await ctx.repo.getMemberCredits(ctx.aliceId), isEmpty);
    });
  });

  group('generator & alokasi', () {
    test('generator periode idempoten', () async {
      final ctx = await seedWeekly();
      final first = await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 19));
      final second = await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 19));

      expect(first, 3);
      expect(second, 0);
      final periods = await ctx.repo.getPeriods(ctx.groupId);
      expect(periods, hasLength(3));
      for (final period in periods) {
        expect(await ctx.repo.getPeriodRows(period.id), hasLength(2));
      }
    });

    test('pembayaran sebagian FIFO mengisi periode tertua dulu', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 12));
      final periods = await ctx.repo.getPeriods(ctx.groupId);

      await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 30000,
        date: '2026-01-05',
      );

      final p1 =
          rowFor(await ctx.repo.getPeriodRows(periods[0].id), ctx.aliceId);
      final p2 =
          rowFor(await ctx.repo.getPeriodRows(periods[1].id), ctx.aliceId);
      expect(p1.status, ChargeStatus.paid);
      expect(p2.status, ChargeStatus.partial);
      expect(p2.paid, 10000);
      expect(await ctx.repo.getMemberCredits(ctx.aliceId), isEmpty);
    });

    test(
        'kelebihan bayar menjadi kredit dan otomatis terpakai saat periode baru dibuat',
        () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));

      await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 50000,
        date: '2026-01-05',
      );
      final credits = await ctx.repo.getMemberCredits(ctx.aliceId);
      expect(credits, hasLength(1));
      expect(credits.single.amountRemaining, 30000);

      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 19));
      final periods = await ctx.repo.getPeriods(ctx.groupId);
      expect(periods, hasLength(3));
      expect(
        rowFor(await ctx.repo.getPeriodRows(periods[1].id), ctx.aliceId).status,
        ChargeStatus.paid,
      );
      final p3 =
          rowFor(await ctx.repo.getPeriodRows(periods[2].id), ctx.aliceId);
      expect(p3.status, ChargeStatus.partial);
      expect(p3.paid, 10000);
      expect(await ctx.repo.getMemberCredits(ctx.aliceId), isEmpty);

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 6));
      expect(summary.balance, 50000);
    });

    test('edit setelah kredit terpakai mengembalikan periode menjadi menunggak',
        () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 50000,
        date: '2026-01-05',
      );
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 12));
      final periods = await ctx.repo.getPeriods(ctx.groupId);

      await ctx.repo.editTransaction(id: txId, amount: 20000);

      expect(
        rowFor(await ctx.repo.getPeriodRows(periods[0].id), ctx.aliceId).status,
        ChargeStatus.paid,
      );
      expect(
        rowFor(await ctx.repo.getPeriodRows(periods[1].id), ctx.aliceId).status,
        ChargeStatus.unpaid,
      );
      expect(await ctx.repo.getMemberCredits(ctx.aliceId), isEmpty);
    });

    test('charge waived dilewati pembayaran dan tidak dihitung tunggakan',
        () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final period = (await ctx.repo.getPeriods(ctx.groupId)).single;
      final aliceRow =
          rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId);
      await ctx.repo.setChargeWaived(aliceRow.chargeId, waived: true);

      expect(
        rowFor(await ctx.repo.getPeriodRows(period.id), ctx.aliceId).status,
        ChargeStatus.waived,
      );

      await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
      );
      final credits = await ctx.repo.getMemberCredits(ctx.aliceId);
      expect(credits.single.amountRemaining, 20000,
          reason: 'charge waived tidak boleh menerima alokasi');

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 20));
      expect(summary.overdueTotal, 20000,
          reason: 'hanya tagihan Bob yang menunggak');
      expect(summary.currentPeriodPaidCount, 0);
      expect(summary.currentPeriodTotalCount, 1,
          reason: 'charge waived tidak dihitung');
    });
  });

  group('audit & ringkasan', () {
    test('audit log menyimpan nilai lama dan baru saat edit', () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      final txId = await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 10000,
        date: '2026-01-05',
      );
      await ctx.repo.editTransaction(id: txId, amount: 15000);

      final audit =
          await ctx.repo.getAuditLog(entity: 'transaction', entityId: txId);
      expect(audit.map((e) => e.action).toList(), ['insert', 'update']);
      expect(audit.last.oldJson, contains('10000'));
      expect(audit.last.newJson, contains('15000'));
    });

    test('ringkasan: saldo, tunggakan, dan keaktifan periode berjalan',
        () async {
      final ctx = await seedWeekly();
      await ctx.repo
          .generatePeriods(groupId: ctx.groupId, upTo: DateTime(2026, 1, 5));
      await ctx.repo.recordDuesPayment(
        groupId: ctx.groupId,
        memberId: ctx.aliceId,
        amount: 20000,
        date: '2026-01-05',
      );
      await ctx.repo.recordTransaction(
        groupId: ctx.groupId,
        type: TxType.expense,
        amount: 5000,
        category: 'Konsumsi',
        date: '2026-01-06',
      );

      final summary = await ctx.repo
          .getGroupSummary(groupId: ctx.groupId, asOf: DateTime(2026, 1, 20));
      expect(summary.balance, 15000);
      expect(summary.overdueTotal, 20000);
      expect(summary.currentPeriodLabel, isNotNull);
      expect(summary.currentPeriodPaidCount, 1);
      expect(summary.currentPeriodTotalCount, 2);
      expect(summary.activityPct, 50);
    });
  });
}
