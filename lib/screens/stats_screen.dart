import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/finance_calc.dart';
import '../widgets/donut_chart.dart';

class StatsScreen extends StatefulWidget {
  final VoidCallback? onGoToBudget;
  const StatsScreen({super.key, this.onGoToBudget});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _showIncome = false;

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = ['Januari','Februari','Maret','April','Mei','Juni',
          'Juli','Agustus','September','Oktober','November','Desember'];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) { return s; }
  }

  void _shiftMonth(BuildContext context, String current, int delta) {
    try {
      final p = current.split('-').map(int.parse).toList();
      int y = p[0];
      int m = p[1] + delta;
      if (m < 1) { m = 12; y--; }
      if (m > 12) { m = 1; y++; }
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
      final cat = tx.isTransfer ? 'Transfer' : (tx.categoryName ?? 'Tanpa Kategori');
      final type = tx.isTransfer
          ? 'Transfer'
          : (tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran');
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
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);
    final current = provider.currentMonth;
    final totals = provider.monthlyTotals;
    final income = totals['income'] ?? 0.0;
    final expense = totals['expense'] ?? 0.0;

    final days = daysInMonth(current);
    final budgets = provider.budgets.where((b) => b.limitAmount > 0).toList();
    final totalBudget = budgets.fold(0.0, (s, b) => s + monthlyBudgetLimit(b, days));
    final usagePct = totalBudget > 0 ? expense / totalBudget : 0.0;

    final now = DateTime.now();
    final isCurrentMonth =
        current == '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final elapsedDays = isCurrentMonth ? now.day : days;
    final dailyAvg = expense / (elapsedDays > 0 ? elapsedDays : 1);

    final spending = provider.categorySpending;
    final incomeByCat = provider.categoryIncome;
    final chartData = _showIncome ? incomeByCat : spending;
    final chartTotal = _showIncome ? income : expense;

    return Scaffold(
      backgroundColor: tokens.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ PLUM BANNER ═══════════════════════════════════════════════════
          Container(
            decoration: BoxDecoration(
              color: tokens.headerBg,
              borderRadius: const BorderRadius.only(
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
                        Text(
                          'Statistik',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.headerFg),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _NavBtn(
                              onTap: () => _shiftMonth(context, current, -1),
                              icon: Icons.chevron_left,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _monthName(current),
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: tokens.headerMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NavBtn(
                              onTap: () => _shiftMonth(context, current, 1),
                              icon: Icons.chevron_right,
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _exportCSV(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: tokens.headerSurface,
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                          border: Border.all(color: tokens.headerBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 14, color: tokens.headerMuted),
                            SizedBox(width: 6),
                            Text('Ekspor', style: TextStyle(fontSize: 12, color: tokens.headerMuted, fontWeight: FontWeight.w600)),
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
                // Analytics donut: spending / income
                _AnalyticsCard(
                  showIncome: _showIncome,
                  data: chartData,
                  total: chartTotal,
                  usagePct: (!_showIncome && totalBudget > 0) ? usagePct : null,
                  provider: provider,
                  colorOf: _color,
                  onToggle: (income) => setState(() => _showIncome = income),
                ),
                const SizedBox(height: 14),

                // Weekly expense flow
                _WeeklyExpenseCard(
                  transactions: provider.transactions,
                  currentMonth: current,
                  provider: provider,
                ),
                const SizedBox(height: 14),

                // Monthly summary
                _SummaryCard(
                  expense: expense,
                  totalBudget: totalBudget,
                  usagePct: usagePct,
                  dailyAvg: dailyAvg,
                  provider: provider,
                  onGoToBudget: widget.onGoToBudget,
                ),
                const SizedBox(height: 24),

                // Budget positions monitor
                _PosMonitor(
                  budgets: budgets,
                  categories: provider.categories,
                  days: days,
                  provider: provider,
                  onGoToBudget: widget.onGoToBudget,
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
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: tokens.headerSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.headerBorder, width: 1),
        ),
        child: Icon(icon, color: tokens.headerFg, size: 16),
      ),
    );
  }
}

// ─── Analytics Card (donut + toggle + legend) ────────────────────────────────
class _AnalyticsCard extends StatelessWidget {
  final bool showIncome;
  final List<Map<String, dynamic>> data;
  final double total;
  final double? usagePct;
  final FinanceProvider provider;
  final Color Function(String) colorOf;
  final ValueChanged<bool> onToggle;

  const _AnalyticsCard({
    required this.showIncome,
    required this.data,
    required this.total,
    required this.usagePct,
    required this.provider,
    required this.colorOf,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (data.isEmpty || total <= 0) {
      return _EmptyChart(showIncome: showIncome);
    }

    final donutItems = data.map((item) => DonutChartItem(
      value: (item['amount'] as num).toDouble(),
      color: colorOf(item['color'] as String),
    )).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showIncome ? 'Analitika Pemasukan' : 'Analitika Pengeluaran',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary,
                  ),
                ),
                _ModeToggle(showIncome: showIncome, onToggle: onToggle),
              ],
            ),
            const SizedBox(height: 20),

            // Donut
            DonutChart(
              items: donutItems,
              size: 190,
              strokeWidth: 20,
              centerWidget: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    usagePct != null ? 'TOTAL TERPAKAI' : 'TOTAL',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: tokens.textMuted, letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (usagePct != null)
                    Text(
                      '${(usagePct! * 100).round()}%',
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: tokens.textPrimary,
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.formatCurrency(total),
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: tokens.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 0.5, color: tokens.border),
            const SizedBox(height: 12),

            // Legend list
            ...data.map((item) {
              final val = (item['amount'] as num).toDouble();
              final col = colorOf(item['color'] as String);
              final name = item['category_name'] as String;
              final pct = total > 0 ? (val / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      provider.formatCurrency(val),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${pct.round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Mode toggle (Pengeluaran / Pemasukan) ───────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final bool showIncome;
  final ValueChanged<bool> onToggle;

  const _ModeToggle({required this.showIncome, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget tab(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? tokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? tokens.onAccent : tokens.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.softSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          tab('Keluar', !showIncome, () => onToggle(false)),
          tab('Masuk', showIncome, () => onToggle(true)),
        ],
      ),
    );
  }
}

// ─── Weekly Expense Card ──────────────────────────────────────────────────────
class _WeeklyExpenseCard extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final String currentMonth;
  final FinanceProvider provider;

  const _WeeklyExpenseCard({
    required this.transactions,
    required this.currentMonth,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final monthlyTxs =
        transactions.where((tx) => tx.date.startsWith(currentMonth)).toList();

    final weeks = List.generate(5, (_) => <FinanceTransaction>[]);
    for (final tx in monthlyTxs) {
      try {
        final day = DateTime.parse(tx.date).day;
        final weekIndex = ((day - 1) / 7).floor().clamp(0, 4);
        weeks[weekIndex].add(tx);
      } catch (_) {}
    }

    final amounts = weeks.map(sumExpense).toList();
    final total = amounts.fold(0.0, (s, a) => s + a);
    final weeksWithData = amounts.where((a) => a > 0).length;
    final avg = weeksWithData > 0 ? total / weeksWithData : 0.0;
    final maxVal = amounts.fold(0.0, (m, a) => a > m ? a : m);
    final safeMax = maxVal > 0 ? maxVal : 1.0;
    const maxBarHeight = 110.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arus Pengeluaran',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Rata-rata ${provider.formatCurrency(avg)}/minggu',
              style: TextStyle(fontSize: 11, color: tokens.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (index) {
                final amt = amounts[index];
                final height = (amt / safeMax) * maxBarHeight;
                final isHighest = amt > 0 && amt == maxVal;

                return GestureDetector(
                  onTap: () {
                    if (amt <= 0) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Minggu ${index + 1}: ${provider.formatCurrency(amt)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 20,
                        height: height.clamp(6.0, maxBarHeight),
                        decoration: BoxDecoration(
                          color: amt <= 0
                              ? tokens.border.withValues(alpha: 0.5)
                              : isHighest
                                  ? tokens.expense
                                  : tokens.expense.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'M${index + 1}',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Monthly Summary Card ─────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double expense, totalBudget, usagePct, dailyAvg;
  final FinanceProvider provider;
  final VoidCallback? onGoToBudget;

  const _SummaryCard({
    required this.expense,
    required this.totalBudget,
    required this.usagePct,
    required this.dailyAvg,
    required this.provider,
    this.onGoToBudget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasBudget = totalBudget > 0;
    final pct = hasBudget ? usagePct : 0.0;
    final badgeColor = pct > 0.85
        ? tokens.expenseOnHeader
        : pct > 0.6
            ? tokens.warning
            : tokens.incomeOnHeader;
    final remaining = totalBudget - expense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.headerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Bulan Ini',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.headerFg),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasBudget
                      ? badgeColor.withValues(alpha: 0.18)
                      : tokens.headerSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasBudget ? '${(pct * 100).round()}% terpakai' : 'Belum ada anggaran',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: hasBudget ? badgeColor : tokens.headerMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Total Pengeluaran',
            style: TextStyle(fontSize: 11, color: tokens.headerMuted),
          ),
          const SizedBox(height: 4),
          Text(
            provider.formatCurrency(expense),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: tokens.headerFg),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 8, color: tokens.headerSurface),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rata-rata Harian',
                      style: TextStyle(fontSize: 11, color: tokens.headerMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.formatCurrency(dailyAvg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.headerFg),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sisa Anggaran',
                      style: TextStyle(fontSize: 11, color: tokens.headerMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasBudget ? provider.formatCurrency(remaining) : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasBudget
                            ? (remaining >= 0 ? tokens.incomeOnHeader : tokens.expenseOnHeader)
                            : tokens.headerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasBudget && onGoToBudget != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onGoToBudget,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.headerSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.headerBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 14, color: tokens.headerFg),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Atur anggaran sekarang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.headerFg),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: tokens.headerFg),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Budget Positions Monitor ─────────────────────────────────────────────────
class _PosMonitor extends StatelessWidget {
  final List<Budget> budgets;
  final List<Category> categories;
  final int days;
  final FinanceProvider provider;
  final VoidCallback? onGoToBudget;

  const _PosMonitor({
    required this.budgets,
    required this.categories,
    required this.days,
    required this.provider,
    this.onGoToBudget,
  });

  IconData _icon(String name) {
    switch (name) {
      case 'fast_food': return Icons.fastfood_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'cart': return Icons.shopping_cart_rounded;
      case 'gamepad_2': return Icons.sports_esports_rounded;
      case 'heart_pulse': return Icons.favorite_rounded;
      case 'receipt': return Icons.receipt_long_rounded;
      case 'banknote': return Icons.payments_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'gift': return Icons.redeem_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  Color _color(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PEMANTAUAN POS PENGELUARAN',
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: tokens.textPrimary, letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Slider Batas & Realisasi',
          style: TextStyle(fontSize: 11, color: tokens.textMuted),
        ),
        const SizedBox(height: 12),
        if (budgets.isEmpty)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onGoToBudget,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: tokens.softSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.pie_chart_outline_rounded, color: tokens.textMuted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Belum ada pos anggaran. Tekan untuk mengatur batas pengeluaran per kategori.',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.5),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: tokens.textMuted),
                  ],
                ),
              ),
            ),
          )
        else
          ...budgets.map((b) {
            final cat = categories.where((c) => c.id == b.categoryId);
            final catName = cat.isNotEmpty ? cat.first.name : 'Kategori';
            final catIcon = cat.isNotEmpty ? cat.first.icon : 'ellipsis';
            final catColor = cat.isNotEmpty ? _color(cat.first.color) : Colors.grey;
            final limit = monthlyBudgetLimit(b, days);
            final spent = b.totalSpent ?? 0.0;
            final pct = limit > 0 ? spent / limit : 0.0;
            final clamped = pct.clamp(0.0, 1.0);
            final barColor = pct > 0.85
                ? tokens.expense
                : pct > 0.6
                    ? tokens.warning
                    : tokens.income;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: catColor,
                            child: Icon(_icon(catIcon), color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              catName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: barColor,
                                ),
                              ),
                              Text(
                                provider.formatCurrency(spent),
                                style: TextStyle(
                                  fontSize: 10, color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      IgnorePointer(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: barColor,
                            inactiveTrackColor: tokens.softSurface,
                            thumbColor: barColor,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            overlayColor: barColor.withValues(alpha: 0.12),
                          ),
                          child: Slider(
                            value: clamped,
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Realisasi ${provider.formatCurrency(spent)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: tokens.textMuted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              b.budgetType == 'daily_limit'
                                  ? 'Batas ${provider.formatCurrency(b.limitAmount)}/hari'
                                  : 'Batas ${provider.formatCurrency(limit)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10, color: tokens.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── Empty Chart ──────────────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  final bool showIncome;
  const _EmptyChart({this.showIncome = false});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: tokens.softSurface,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border),
              ),
              child: Icon(Icons.bar_chart_rounded, size: 32, color: tokens.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              showIncome ? 'Belum ada data pemasukan' : 'Belum ada data pengeluaran',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan transaksi untuk melihat diagram di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
