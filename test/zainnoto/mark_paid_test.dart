import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/zainnoto/models/derived.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

class _Ctx {
  _Ctx({
    required this.repo,
    required this.provider,
    required this.groupId,
    required this.mayaId,
    required this.dewiId,
  });

  final ZainNotoRepository repo;
  final ZainNotoProvider provider;
  final String groupId;
  final String mayaId;
  final String dewiId;
}

Future<_Ctx> _seeded() async {
  final db = await openTestDatabase();
  await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
  final repo = ZainNotoRepository();
  final provider = ZainNotoProvider(
    repository: repo,
    now: () => DateTime(2026, 10, 21),
  );
  await provider.loadGroups();
  final groupId = provider.selectedGroup!.id;
  final maya = provider.members.firstWhere((m) => m.name == 'Maya');
  final dewi = provider.members.firstWhere((m) => m.name == 'Dewi');
  return _Ctx(
    repo: repo,
    provider: provider,
    groupId: groupId,
    mayaId: maya.id,
    dewiId: dewi.id,
  );
}

Future<PeriodMemberRow> _row(
  _Ctx ctx,
  String periodLabel,
  String memberName,
) async {
  final periods = await ctx.repo.getPeriods(ctx.groupId);
  final period = periods.firstWhere((p) => p.label == periodLabel);
  final rows = await ctx.repo.getPeriodRows(period.id);
  return rows.firstWhere((r) => r.memberName == memberName);
}

int _creditTotal(List<MemberCredit> credits) =>
    credits.fold(0, (sum, credit) => sum + credit.amountRemaining);

void main() {
  test('(a) bayar lebih: kredit dipakai di periode berikutnya', () async {
    // Hitungan tangan:
    // Maya Oktober: due 50.000, seed sudah bayar 25.000 -> sisa 25.000.
    // Bayar 60.000 -> 25.000 melunasi Oktober, sisa 35.000 menjadi kredit.
    // Generate November (due 50.000): kredit 35.000 dipakai ->
    //   November paid 35.000, sisa 15.000, kredit tersisa 0.
    final ctx = await _seeded();

    final id = await ctx.provider.markPaid(
      memberId: ctx.mayaId,
      amount: 60000,
      date: '2026-10-21',
    );
    expect(id, isNotNull);

    final okt = await _row(ctx, 'Oktober 2026', 'Maya');
    expect(okt.paid, 50000);
    expect(okt.remaining, 0);
    expect(_creditTotal(await ctx.repo.getMemberCredits(ctx.mayaId)), 35000);

    await ctx.repo.generatePeriods(
      groupId: ctx.groupId,
      upTo: DateTime(2026, 11, 21),
    );

    final nov = await _row(ctx, 'November 2026', 'Maya');
    expect(nov.paid, 35000);
    expect(nov.remaining, 15000);
    expect(_creditTotal(await ctx.repo.getMemberCredits(ctx.mayaId)), 0);
  });

  test('(b) bayar tunggakan: FIFO ke periode terlama', () async {
    // Hitungan tangan:
    // Dewi: Juli 50.000 lunas, Agustus 50.000 lunas, September 0/50.000,
    // Oktober 0/50.000.
    // Bayar 60.000 -> September 50.000 (lunas), Oktober 10.000 (sisa 40.000).
    final ctx = await _seeded();

    final id = await ctx.provider.markPaid(
      memberId: ctx.dewiId,
      amount: 60000,
      date: '2026-10-21',
    );
    expect(id, isNotNull);

    final sep = await _row(ctx, 'September 2026', 'Dewi');
    expect(sep.paid, 50000);
    expect(sep.remaining, 0);
    final okt = await _row(ctx, 'Oktober 2026', 'Dewi');
    expect(okt.paid, 10000);
    expect(okt.remaining, 40000);

    final allocations = await ctx.repo.getAllocationDetails(id!);
    expect(
      {
        for (final a in allocations) a.periodLabel: a.amountAllocated,
      },
      {'September 2026': 50000, 'Oktober 2026': 10000},
    );
  });

  test('(c) note tersimpan pada transaksi', () async {
    // Hitungan tangan:
    // Maya Oktober: paid 25.000 + cicilan 10.000 = 35.000, sisa 15.000.
    // Transaksi menyimpan note 'Cicilan minggu ke-3'.
    final ctx = await _seeded();

    final id = await ctx.provider.markPaid(
      memberId: ctx.mayaId,
      amount: 10000,
      date: '2026-10-21',
      note: 'Cicilan minggu ke-3',
    );
    expect(id, isNotNull);

    final tx = ctx.provider.transactions.firstWhere((t) => t.id == id);
    expect(tx.type, TxType.dues);
    expect(tx.memberId, ctx.mayaId);
    expect(tx.amount, 10000);
    expect(tx.note, 'Cicilan minggu ke-3');

    final okt = await _row(ctx, 'Oktober 2026', 'Maya');
    expect(okt.paid, 35000);
    expect(okt.remaining, 15000);
  });

  test('(d) amount <= 0 atau tanpa grup: null dan tidak mencatat', () async {
    // Hitungan tangan: tidak ada transaksi baru, paid Maya tetap 25.000.
    final ctx = await _seeded();
    final before = (await ctx.repo.getTransactions(ctx.groupId)).length;

    expect(
      await ctx.provider.markPaid(
        memberId: ctx.mayaId,
        amount: 0,
        date: '2026-10-21',
      ),
      isNull,
    );
    expect(
      await ctx.provider.markPaid(
        memberId: ctx.mayaId,
        amount: -1,
        date: '2026-10-21',
      ),
      isNull,
    );

    final noGroup = ZainNotoProvider(
      repository: ctx.repo,
      now: () => DateTime(2026, 10, 21),
    );
    expect(noGroup.selectedGroup, isNull);
    expect(
      await noGroup.markPaid(memberId: ctx.mayaId, amount: 10000),
      isNull,
    );

    final after = await ctx.repo.getTransactions(ctx.groupId);
    expect(after.length, before);
    final okt = await _row(ctx, 'Oktober 2026', 'Maya');
    expect(okt.paid, 25000);
  });

  test('(e) idempotency key repository vs panggilan provider ganda', () async {
    // Hitungan tangan:
    // Repository dengan key sama dua kali -> satu transaksi 10.000,
    //   Oktober paid 25.000 + 10.000 = 35.000.
    // Provider membuat key baru tiap panggilan -> dua transaksi 10.000,
    //   total paid 35.000 + 20.000 = 55.000; Oktober maksimal 50.000
    //   sehingga sisa 5.000 menjadi kredit.
    final ctx = await _seeded();

    final first = await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.mayaId,
      amount: 10000,
      date: '2026-10-21',
      idempotencyKey: 'tap-1',
    );
    final second = await ctx.repo.recordDuesPayment(
      groupId: ctx.groupId,
      memberId: ctx.mayaId,
      amount: 10000,
      date: '2026-10-21',
      idempotencyKey: 'tap-1',
    );
    expect(second, first);
    var dues = await ctx.repo.getTransactions(
      ctx.groupId,
      type: TxType.dues,
    );
    expect(dues.where((t) => t.id == first).length, 1);
    expect((await _row(ctx, 'Oktober 2026', 'Maya')).paid, 35000);

    final p1 = await ctx.provider.markPaid(
      memberId: ctx.mayaId,
      amount: 10000,
      date: '2026-10-21',
    );
    final p2 = await ctx.provider.markPaid(
      memberId: ctx.mayaId,
      amount: 10000,
      date: '2026-10-21',
    );
    expect(p1, isNotNull);
    expect(p2, isNotNull);
    expect(p2, isNot(p1));

    dues = await ctx.repo.getTransactions(ctx.groupId, type: TxType.dues);
    expect(dues.where((t) => t.id == p1).length, 1);
    expect(dues.where((t) => t.id == p2).length, 1);

    final okt = await _row(ctx, 'Oktober 2026', 'Maya');
    expect(okt.paid, 50000);
    expect(_creditTotal(await ctx.repo.getMemberCredits(ctx.mayaId)), 5000);
  });
}
