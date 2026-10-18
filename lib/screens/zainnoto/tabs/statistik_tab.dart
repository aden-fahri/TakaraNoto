import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/decorative_header_circles.dart';
import '../../../widgets/donut_chart.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/format.dart';
import '../widgets/member_avatar.dart';

/// Statistik tab for ZainNoto (Kas Kelompok):
/// - Kas Summary (Saldo, Pemasukan Iuran + Lain, Pengeluaran)
/// - Visual Donut Chart (Breakdown Pemasukan vs Pengeluaran & Kategori)
/// - Tingkat Kepatuhan Anggota (Lunas vs Tunggakan)
/// - Daftar Kontribusi Anggota & Tunggakan
class StatistikTab extends StatelessWidget {
  const StatistikTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;

    if (group == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 48, color: t.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Grup',
              style: TextStyle(
                fontSize: AppText.title,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih atau buat grup di tab Beranda untuk melihat statistik.',
              style: TextStyle(fontSize: AppText.body, color: t.textMuted),
            ),
          ],
        ),
      );
    }

    final income = provider.totalIncome;
    final expense = provider.totalExpense;
    final balance = provider.summary?.balance ?? 0;
    final overdueTotal = provider.summary?.overdueTotal ?? 0;
    final overdueCount = provider.summary?.overdueMemberCount ?? 0;
    final totalMembers = provider.members.length;
    final activeRate = totalMembers > 0
        ? (((totalMembers - overdueCount) / totalMembers) * 100).round()
        : 100;

    // Expenses by category
    final expenseByCat = <String, int>{};
    for (final tx in provider.transactions) {
      if (tx.type == TxType.expense) {
        final cat = tx.category ?? 'Lain-lain';
        expenseByCat[cat] = (expenseByCat[cat] ?? 0) + tx.amount;
      }
    }

    // Chart items
    final chartColors = [
      t.accent,
      t.income,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    final chartItems = <DonutChartItem>[];
    int colorIdx = 0;
    if (expenseByCat.isNotEmpty) {
      for (final entry in expenseByCat.entries) {
        chartItems.add(
          DonutChartItem(
            value: entry.value.toDouble(),
            color: chartColors[colorIdx % chartColors.length],
          ),
        );
        colorIdx++;
      }
    } else if (expense > 0) {
      chartItems.add(DonutChartItem(value: expense.toDouble(), color: t.expense));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(groupName: group.name),
        if (provider.isRefreshing)
          LinearProgressIndicator(
            minHeight: 2,
            color: t.accent,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: RefreshIndicator(
            color: t.accent,
            onRefresh: provider.refreshGroup,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Financial Overview Card
                _FinancialCard(
                  balance: balance,
                  income: income,
                  expense: expense,
                ),
                const SizedBox(height: 16),

                // Compliance Metric Card
                _ComplianceCard(
                  activeRate: activeRate,
                  totalMembers: totalMembers,
                  overdueCount: overdueCount,
                  overdueTotal: overdueTotal,
                ),
                const SizedBox(height: 16),

                // Expense Breakdown Chart
                _ExpenseBreakdownCard(
                  totalExpense: expense,
                  expenseByCat: expenseByCat,
                  chartItems: chartItems,
                  colors: chartColors,
                ),
                const SizedBox(height: 16),

                // Member Ranking / Leaderboard
                _MemberContributionCard(provider: provider),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  const _Banner({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.headerBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const DecorativeHeaderCircles(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistik & Laporan',
                    style: TextStyle(
                      fontSize: AppText.headline,
                      fontWeight: FontWeight.w800,
                      color: t.headerFg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppText.body, color: t.headerMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Financial Card ───────────────────────────────────────────────────────────
class _FinancialCard extends StatelessWidget {
  const _FinancialCard({
    required this.balance,
    required this.income,
    required this.expense,
  });

  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo Bersih Kas',
            style: TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w500,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(balance),
              style: TextStyle(
                fontSize: AppText.displayLarge,
                fontWeight: FontWeight.w800,
                color: balance >= 0 ? t.textPrimary : t.expense,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  icon: Icons.south_west_rounded,
                  label: 'Total Pemasukan',
                  value: formatRupiah(income),
                  color: t.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  icon: Icons.north_east_rounded,
                  label: 'Total Pengeluaran',
                  value: formatRupiah(expense),
                  color: t.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppText.micro, color: t.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppText.bodyLarge,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compliance Card ──────────────────────────────────────────────────────────
class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({
    required this.activeRate,
    required this.totalMembers,
    required this.overdueCount,
    required this.overdueTotal,
  });

  final int activeRate;
  final int totalMembers;
  final int overdueCount;
  final int overdueTotal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 18, color: t.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Kepatuhan Kas',
                    style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (activeRate >= 80 ? t.income : t.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeRate% Tertib',
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w700,
                    color: activeRate >= 80 ? t.income : t.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: activeRate / 100,
              minHeight: 8,
              color: activeRate >= 80 ? t.income : t.warning,
              backgroundColor: t.border,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tertib: ${totalMembers - overdueCount} dari $totalMembers anggota',
                  style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                ),
              ),
              if (overdueTotal > 0)
                Text(
                  'Tunggakan: ${formatRupiah(overdueTotal)}',
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w700,
                    color: t.expense,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Expense Breakdown Card ───────────────────────────────────────────────────
class _ExpenseBreakdownCard extends StatelessWidget {
  const _ExpenseBreakdownCard({
    required this.totalExpense,
    required this.expenseByCat,
    required this.chartItems,
    required this.colors,
  });

  final int totalExpense;
  final Map<String, int> expenseByCat;
  final List<DonutChartItem> chartItems;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alokasi Pengeluaran Kas',
            style: TextStyle(
              fontSize: AppText.subtitle,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (totalExpense == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada transaksi pengeluaran.',
                  style: TextStyle(fontSize: AppText.body, color: t.textMuted),
                ),
              ),
            )
          else ...[
            Center(
              child: DonutChart(
                items: chartItems,
                size: 130,
                strokeWidth: 14,
                centerWidget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(fontSize: AppText.micro, color: t.textMuted),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatRupiah(totalExpense),
                        style: TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w800,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: expenseByCat.entries.map((entry) {
                final idx = expenseByCat.keys.toList().indexOf(entry.key);
                final color = colors[idx % colors.length];
                final pct = totalExpense > 0
                    ? ((entry.value / totalExpense) * 100).round()
                    : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: AppText.body,
                            color: t.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$pct% · ${formatRupiah(entry.value)}',
                        style: TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Member Contribution Card ─────────────────────────────────────────────────
class _MemberContributionCard extends StatelessWidget {
  const _MemberContributionCard({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final members = provider.members;

    // Calculate total paid per member
    final paidByMember = <String, int>{};
    for (final tx in provider.transactions) {
      if (tx.type == TxType.dues && tx.memberId != null) {
        paidByMember[tx.memberId!] =
            (paidByMember[tx.memberId!] ?? 0) + tx.amount;
      }
    }

    final sortedMembers = [...members]..sort((a, b) {
        final paidA = paidByMember[a.id] ?? 0;
        final paidB = paidByMember[b.id] ?? 0;
        return paidB.compareTo(paidA);
      });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kontribusi Anggota',
                style: TextStyle(
                  fontSize: AppText.subtitle,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              Text(
                '${members.length} Orang',
                style: TextStyle(fontSize: AppText.label, color: t.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sortedMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'Belum ada anggota terdaftar.',
                  style: TextStyle(fontSize: AppText.body, color: t.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedMembers.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final m = sortedMembers[idx];
                final paid = paidByMember[m.id] ?? 0;
                final isTop = idx == 0 && paid > 0;

                return Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w700,
                          color: isTop ? t.accent : t.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MemberAvatar(
                      name: m.name,
                      color: isTop ? t.accent : t.textMuted,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatRupiah(paid),
                      style: TextStyle(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w700,
                        color: paid > 0 ? t.income : t.textMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

