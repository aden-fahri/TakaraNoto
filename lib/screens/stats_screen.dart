import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/donut_chart.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = ['Januari','Februari','Maret','April','Mei','Juni',
          'Juli','Agustus','September','Oktober','November','Desember'];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) { return s; }
  }

  void _prevMonth(BuildContext context, String current) {
    try {
      final p = current.split('-').map(int.parse).toList();
      int y = p[0], m = p[1] - 1;
      if (m == 0) { m = 12; y--; }
      Provider.of<FinanceProvider>(context, listen: false)
          .changeMonth('$y-${m.toString().padLeft(2, '0')}');
    } catch (_) {}
  }

  void _nextMonth(BuildContext context, String current) {
    try {
      final p = current.split('-').map(int.parse).toList();
      int y = p[0], m = p[1] + 1;
      if (m == 13) { m = 1; y++; }
      Provider.of<FinanceProvider>(context, listen: false)
          .changeMonth('$y-${m.toString().padLeft(2, '0')}');
    } catch (_) {}
  }

  Color _color(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  Future<void> _exportCSV(BuildContext context, FinanceProvider provider) async {
    final current = provider.currentMonth;
    final txs = provider.transactions.where((t) => t.date.startsWith(current)).toList();
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada transaksi untuk diekspor!')),
      );
      return;
    }
    String csv = 'Tanggal,Kategori,Tipe,Nominal,Catatan\n';
    for (final tx in txs) {
      final cat = tx.categoryName ?? 'Tanpa Kategori';
      final type = tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
      csv += '"${tx.date}","$cat","$type",${tx.amount},"${tx.note}"\n';
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: csv, subject: 'Laporan_TakaraNoto_$current.csv'),
      );
    } catch (e) { debugPrint('Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final current = provider.currentMonth;
    final totals = provider.monthlyTotals;
    final income = totals['income'] ?? 0.0;
    final expense = totals['expense'] ?? 0.0;

    // Savings rate calculation
    final savingsAmount = income - expense;
    final savingsRate = income > 0 ? (savingsAmount / income * 100).round() : 0;
    final savingsColor = savingsRate >= 20 ? AppTheme.emeraldGreen
        : savingsRate >= 0 ? AppTheme.amberAccent
        : AppTheme.roseRed;

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ PLUM BANNER ═══════════════════════════════════════════════════
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.darkPlum,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistik',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.warmCream),
                        ),
                        const SizedBox(height: 8),
                        // Month navigator
                        Row(
                          children: [
                            _NavBtn(onTap: () => _prevMonth(context, current), icon: Icons.chevron_left),
                            const SizedBox(width: 8),
                            Text(
                              _monthName(current),
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppTheme.mutedDarkLavender,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NavBtn(onTap: () => _nextMonth(context, current), icon: Icons.chevron_right),
                          ],
                        ),
                      ],
                    ),
                    // Export button
                    GestureDetector(
                      onTap: () => _exportCSV(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.share_outlined, size: 14, color: AppTheme.mutedDarkLavender),
                            SizedBox(width: 6),
                            Text('Ekspor', style: TextStyle(fontSize: 12, color: AppTheme.mutedDarkLavender, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ══ CONTENT ═══════════════════════════════════════════════════════
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // Wide Summary Card
                _WideSummaryCard(income: income, expense: expense, provider: provider),
                const SizedBox(height: 14),

                // Savings Rate Chip
                if (income > 0) ...[
                  _SavingsRateChip(
                    savingsRate: savingsRate,
                    savingsAmount: savingsAmount,
                    savingsColor: savingsColor,
                    provider: provider,
                  ),
                  const SizedBox(height: 20),
                ],

                // Weekly Cash Flow Bar Chart (Richer Stats)
                if (income > 0 || expense > 0) ...[
                  _WeeklyBarChart(
                    transactions: provider.transactions,
                    currentMonth: current,
                    provider: provider,
                  ),
                  const SizedBox(height: 28),
                ],

                // Spending Chart
                Text(
                  'Struktur Pengeluaran',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: provider.getCategorySpendingList(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: AppTheme.darkPlum),
                        ),
                      );
                    }
                    final spending = snapshot.data ?? [];
                    if (expense <= 0 || spending.isEmpty) return _EmptyChart();

                    final donutItems = spending.map((item) => DonutChartItem(
                      value: (item['amount'] as num).toDouble(),
                      color: _color(item['color'] as String),
                    )).toList();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Donut 180px
                            DonutChart(
                              items: donutItems,
                              size: 180,
                              strokeWidth: 18,
                              centerWidget: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                        color: AppTheme.mutedLightPlum, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      provider.formatCurrency(expense),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkPlum),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(height: 0.5, color: AppTheme.borderLight),
                            const SizedBox(height: 20),

                            // 2-column legend grid
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 2.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              children: spending.map((item) {
                                final val = (item['amount'] as num).toDouble();
                                final col = _color(item['color'] as String);
                                final name = item['category_name'] as String;
                                final pct = (val / expense * 100).round();

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: col.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10, height: 10,
                                        decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
                                            Text('$pct%',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.mutedLightPlum)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Button ───────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const _NavBtn({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─── Wide Summary Card ────────────────────────────────────────────────────────
class _WideSummaryCard extends StatelessWidget {
  final double income, expense;
  final FinanceProvider provider;

  const _WideSummaryCard({required this.income, required this.expense, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.emeraldGreen, size: 15),
                        ),
                        const SizedBox(width: 8),
                        const Text('Pemasukan',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      provider.formatCurrency(income),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 32, thickness: 0.5, color: AppTheme.borderLight),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.roseRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: AppTheme.roseRed, size: 15),
                        ),
                        const SizedBox(width: 8),
                        const Text('Pengeluaran',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      provider.formatCurrency(expense),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.roseRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Savings Rate Chip ────────────────────────────────────────────────────────
class _SavingsRateChip extends StatelessWidget {
  final int savingsRate;
  final double savingsAmount;
  final Color savingsColor;
  final FinanceProvider provider;

  const _SavingsRateChip({
    required this.savingsRate,
    required this.savingsAmount,
    required this.savingsColor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final label = savingsRate >= 20 ? 'Bagus! Tabungan Anda sehat 🎉'
        : savingsRate >= 0 ? 'Kurangi pengeluaran untuk menabung lebih'
        : 'Pengeluaran melebihi pemasukan ⚠️';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: savingsColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: savingsColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: savingsColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$savingsRate%',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: savingsColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Rate bulan ini',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.mutedLightPlum),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: savingsColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                savingsAmount >= 0 ? '+' : '',
                style: TextStyle(fontSize: 10, color: savingsColor),
              ),
              Text(
                provider.formatCurrency(savingsAmount),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: savingsColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Cash Flow Bar Chart Widget ─────────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final String currentMonth;
  final FinanceProvider provider;

  const _WeeklyBarChart({
    required this.transactions,
    required this.currentMonth,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyTxs = transactions.where((tx) => tx.date.startsWith(currentMonth)).toList();

    // 5 Weeks breakdown:
    // W1 (1-7), W2 (8-14), W3 (15-21), W4 (22-28), W5 (29+)
    List<double> weeklyIncome = [0.0, 0.0, 0.0, 0.0, 0.0];
    List<double> weeklyExpense = [0.0, 0.0, 0.0, 0.0, 0.0];

    for (final tx in monthlyTxs) {
      try {
        final date = DateTime.parse(tx.date);
        final day = date.day;
        int weekIndex = 0;
        if (day <= 7) {
          weekIndex = 0;
        } else if (day <= 14) {
          weekIndex = 1;
        } else if (day <= 21) {
          weekIndex = 2;
        } else if (day <= 28) {
          weekIndex = 3;
        } else {
          weekIndex = 4;
        }

        if (tx.type == 'income') {
          if (tx.savingsGoalId != null) {
            weeklyExpense[weekIndex] -= tx.amount;
          } else {
            weeklyIncome[weekIndex] += tx.amount;
          }
        } else {
          weeklyExpense[weekIndex] += tx.amount;
        }
      } catch (_) {}
    }

    double maxVal = 0.0;
    for (int i = 0; i < 5; i++) {
      if (weeklyIncome[i] > maxVal) maxVal = weeklyIncome[i];
      if (weeklyExpense[i] > maxVal) maxVal = weeklyExpense[i];
    }
    if (maxVal == 0.0) maxVal = 1.0;

    const double maxBarHeight = 110.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Arus Kas Mingguan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkPlum,
                  ),
                ),
                Row(
                  children: [
                    _LegendDot(color: AppTheme.emeraldGreen, label: 'Masuk'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.roseRed, label: 'Keluar'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (index) {
                final inc = weeklyIncome[index];
                final exp = weeklyExpense[index];
                final double incHeight = (inc / maxVal) * maxBarHeight;
                final double expHeight = (exp / maxVal) * maxBarHeight;

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _BarColumn(
                          height: incHeight.clamp(4.0, maxBarHeight),
                          color: AppTheme.emeraldGreen,
                          value: inc,
                          provider: provider,
                        ),
                        const SizedBox(width: 4),
                        _BarColumn(
                          height: expHeight.clamp(4.0, maxBarHeight),
                          color: AppTheme.roseRed,
                          value: exp,
                          provider: provider,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mng ${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedLightPlum,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  final double height;
  final Color color;
  final double value;
  final FinanceProvider provider;

  const _BarColumn({
    required this.height,
    required this.color,
    required this.value,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (value > 0) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Total: ${provider.formatCurrency(value)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 13,
        height: height,
        decoration: BoxDecoration(
          color: value > 0 ? color : color.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Empty Chart ──────────────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHeroLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 32, color: AppTheme.mutedLightPlum),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada data pengeluaran',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
            const SizedBox(height: 6),
            const Text(
              'Tambahkan transaksi pengeluaran untuk\nmelihat diagram di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
