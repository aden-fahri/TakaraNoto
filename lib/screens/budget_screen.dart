import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_modal.dart';
import '../widgets/donut_chart.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = ['Januari','Februari','Maret','April','Mei','Juni',
          'Juli','Agustus','September','Oktober','November','Desember'];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) { return s; }
  }

  int _daysInMonth(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      // Last day of current month is 0th day of next month
      return DateTime(year, month + 1, 0).day;
    } catch (_) {
      return 30;
    }
  }

  double _getMonthlyLimit(Budget b, int days) {
    if (b.budgetType == 'daily_limit') {
      return b.limitAmount * days;
    }
    return b.limitAmount;
  }

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

  void _showBudgetModal(BuildContext context, Category cat, double currentLimit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetModal(category: cat, currentLimit: currentLimit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;
    final budgets = provider.budgets;
    final expenseCats = provider.categories.where((c) => c.type == 'expense').toList();

    final days = _daysInMonth(currentMonth);
    final totalLimit = budgets.fold(0.0, (s, b) => s + _getMonthlyLimit(b, days));
    final totalSpent = budgets.fold(0.0, (s, b) => s + (b.totalSpent ?? 0.0));
    final totalRemaining = totalLimit - totalSpent;
    final usagePct = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final progressColor = usagePct > 0.85 ? AppTheme.roseRed
        : usagePct > 0.6 ? AppTheme.amberAccent
        : AppTheme.emeraldGreen;

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
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _monthName(currentMonth),
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: AppTheme.mutedDarkLavender,
                          ),
                        ),
                        const Text(
                          'Anggaran',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.warmCream),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.pie_chart_rounded, size: 14, color: AppTheme.mutedDarkLavender),
                          SizedBox(width: 6),
                          Text('Bulanan', style: TextStyle(fontSize: 12, color: AppTheme.mutedDarkLavender, fontWeight: FontWeight.w600)),
                        ],
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                // Overall summary card
                if (totalLimit > 0)
                  _OverallCard(
                    totalLimit: totalLimit,
                    totalSpent: totalSpent,
                    totalRemaining: totalRemaining,
                    usagePct: usagePct,
                    progressColor: progressColor,
                    provider: provider,
                    budgets: budgets,
                  )
                else
                  _NoBudgetBanner(
                    onTap: () {
                      if (expenseCats.isNotEmpty) {
                        _showBudgetModal(context, expenseCats.first, 0);
                      }
                    },
                  ),

                const SizedBox(height: 24),
                const Text(
                  'Per Kategori',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkPlum),
                ),
                const SizedBox(height: 12),

                // Category tiles
                ...expenseCats.map((cat) {
                  final budget = budgets.firstWhere(
                    (b) => b.categoryId == cat.id,
                    orElse: () => Budget(
                      categoryId: cat.id!,
                      limitAmount: 0,
                      monthYear: currentMonth,
                      budgetType: 'daily_limit',
                    ),
                  );
                  final limit = _getMonthlyLimit(budget, days);
                  final spent = budget.totalSpent ?? 0.0;
                  final remaining = limit - spent;
                  final hasBudget = budget.id != null && budget.limitAmount > 0;
                  final pct = hasBudget ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                  final barColor = pct > 0.85 ? AppTheme.roseRed
                      : pct > 0.6 ? AppTheme.amberAccent
                      : AppTheme.emeraldGreen;
                  final catColor = _color(cat.color);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BudgetTile(
                      cat: cat,
                      catColor: catColor,
                      hasBudget: hasBudget,
                      budget: budget,
                      limit: limit,
                      spent: spent,
                      remaining: remaining,
                      pct: pct,
                      barColor: barColor,
                      provider: provider,
                      getIcon: _icon,
                      onEdit: () => _showBudgetModal(context, cat, budget.limitAmount),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overall Summary Card ─────────────────────────────────────────────────────
class _OverallCard extends StatelessWidget {
  final double totalLimit, totalSpent, totalRemaining, usagePct;
  final Color progressColor;
  final FinanceProvider provider;
  final List<Budget> budgets;

  const _OverallCard({
    required this.totalLimit, required this.totalSpent,
    required this.totalRemaining, required this.usagePct,
    required this.progressColor, required this.provider,
    required this.budgets,
  });

  @override
  Widget build(BuildContext context) {
    final donutItems = budgets.where((b) => (b.totalSpent ?? 0) > 0).map((b) {
      final c = b.categoryColor != null
          ? Color(int.tryParse(b.categoryColor!.replaceFirst('#', '0xFF')) ?? 0xFF95A5A6)
          : Colors.grey;
      return DonutChartItem(value: b.totalSpent!, color: c);
    }).toList();

    if (donutItems.isEmpty) {
      donutItems.add(DonutChartItem(value: 1, color: AppTheme.borderLight));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkPlum,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Anggaran',
                    style: TextStyle(color: AppTheme.mutedDarkLavender, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  provider.formatCurrency(totalLimit),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(children: [
                    Container(height: 8, color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      widthFactor: usagePct,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('${(usagePct * 100).round()}% terpakai',
                        style: const TextStyle(color: AppTheme.mutedDarkLavender, fontSize: 11)),
                    const Spacer(),
                    Text(
                      'Sisa ${provider.formatCurrency(totalRemaining)}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: totalRemaining >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          DonutChart(
            items: donutItems, size: 80, strokeWidth: 10,
            centerWidget: Text(
              '${(usagePct * 100).round()}%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No Budget Banner ─────────────────────────────────────────────────────────
class _NoBudgetBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NoBudgetBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHeroLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.mutedLightPlum),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Belum ada anggaran',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
                  SizedBox(height: 3),
                  Text(
                    'Tekan tombol di bawah untuk mulai mengatur batas pengeluaran.',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, height: 1.5),
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

// ─── Budget Tile ──────────────────────────────────────────────────────────────
class _BudgetTile extends StatelessWidget {
  final Category cat;
  final Color catColor, barColor;
  final bool hasBudget;
  final Budget budget;
  final double limit, spent, remaining, pct;
  final FinanceProvider provider;
  final IconData Function(String) getIcon;
  final VoidCallback onEdit;

  const _BudgetTile({
    required this.cat, required this.catColor,
    required this.hasBudget, required this.budget,
    required this.limit, required this.spent,
    required this.remaining, required this.pct,
    required this.barColor, required this.provider,
    required this.getIcon, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.25), blurRadius: 8)],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: catColor,
                        child: Icon(getIcon(cat.icon), color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
                          Text(
                            hasBudget
                                ? (budget.budgetType == 'daily_limit'
                                    ? 'Sisa: ${provider.formatCurrency(remaining)} (${provider.formatCurrency(budget.limitAmount)}/hr)'
                                    : 'Sisa: ${provider.formatCurrency(remaining)} (Tujuan)')
                                : 'Belum diatur',
                            style: const TextStyle(fontSize: 11, color: AppTheme.mutedLightPlum),
                          ),
                        ],
                      ),
                    ),
                    if (hasBudget) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(provider.formatCurrency(limit),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkPlum)),
                          Text(
                            budget.budgetType == 'daily_limit'
                                ? 'Batas bulanan'
                                : 'Target tujuan',
                            style: const TextStyle(fontSize: 10, color: AppTheme.mutedLightPlum),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: AppTheme.surfaceHeroLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        hasBudget ? 'Ubah' : 'Atur',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkPlum),
                      ),
                    ),
                  ],
                ),
                if (hasBudget) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(height: 6, color: AppTheme.surfaceHeroLight),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
