import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/finance_calc.dart';
import '../widgets/budget_modal.dart';
import '../widgets/decorative_header_circles.dart';
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

  String _shiftMonth(String s, int delta) {
    try {
      final p = s.split('-');
      var y = int.parse(p[0]);
      var m = int.parse(p[1]) + delta;
      if (m < 1) { m = 12; y--; }
      if (m > 12) { m = 1; y++; }
      return '$y-${m.toString().padLeft(2, '0')}';
    } catch (_) { return s; }
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
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;
    final budgets = provider.budgets;
    final expenseCats = provider.categories.where((c) => c.type == 'expense').toList();

    final days = daysInMonth(currentMonth);
    final totalLimit = budgets.fold(0.0, (s, b) => s + monthlyBudgetLimit(b, days));
    final totalSpent = budgets.fold(0.0, (s, b) => s + (b.totalSpent ?? 0.0));
    final totalRemaining = totalLimit - totalSpent;
    final usagePct = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final progressColor = usagePct > 0.85 ? tokens.expenseOnHeader
        : usagePct > 0.6 ? tokens.warning
        : tokens.incomeOnHeader;

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
              child: Stack(
                children: [
                  const DecorativeHeaderCircles(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anggaran',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.headerFg),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _NavBtn(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: () => provider.changeMonth(_shiftMonth(currentMonth, -1)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    _monthName(currentMonth),
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: tokens.headerMuted,
                                    ),
                                  ),
                                ),
                                _NavBtn(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => provider.changeMonth(_shiftMonth(currentMonth, 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.headerSurface,
                            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                            border: Border.all(color: tokens.headerBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pie_chart_rounded, size: 14, color: tokens.headerMuted),
                              SizedBox(width: 6),
                              Text('Total Bulan Ini', style: TextStyle(fontSize: 12, color: tokens.headerMuted, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                Text(
                  'Per Kategori',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
                  final limit = monthlyBudgetLimit(budget, days);
                  final spent = budget.totalSpent ?? 0.0;
                  final remaining = limit - spent;
                  final hasBudget = budget.id != null && budget.limitAmount > 0;
                  final pct = hasBudget ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                  final barColor = pct > 0.85 ? tokens.expense
                      : pct > 0.6 ? tokens.warning
                      : tokens.income;
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
    final tokens = context.tokens;
    final donutItems = budgets.where((b) => (b.totalSpent ?? 0) > 0).map((b) {
      final c = b.categoryColor != null
          ? Color(int.tryParse(b.categoryColor!.replaceFirst('#', '0xFF')) ?? 0xFF95A5A6)
          : Colors.grey;
      return DonutChartItem(value: b.totalSpent!, color: c);
    }).toList();

    if (donutItems.isEmpty) {
      donutItems.add(DonutChartItem(value: 1, color: tokens.border));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.headerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Anggaran',
                    style: TextStyle(color: tokens.headerMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  provider.formatCurrency(totalLimit),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.headerFg),
                ),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(children: [
                    Container(height: 8, color: tokens.headerSurface),
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
                        style: TextStyle(color: tokens.headerMuted, fontSize: 11)),
                    const Spacer(),
                    Text(
                      'Sisa ${provider.formatCurrency(totalRemaining)}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: totalRemaining >= 0 ? tokens.incomeOnHeader : tokens.expenseOnHeader,
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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tokens.headerFg),
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
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.softSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.pie_chart_outline_rounded, color: tokens.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Belum ada anggaran',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  SizedBox(height: 3),
                  Text(
                    'Tekan tombol di bawah untuk mulai mengatur batas pengeluaran.',
                    style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.5),
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
    final tokens = context.tokens;
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
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                          Text(
                            hasBudget
                                ? 'Sisa: ${provider.formatCurrency(remaining)}'
                                : 'Belum diatur',
                            style: TextStyle(fontSize: 11, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (hasBudget) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(provider.formatCurrency(limit),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                          Text(
                            budget.budgetType == 'daily_limit'
                                ? 'Harian ${provider.formatCurrency(budget.limitAmount)}'
                                : 'Batas bulanan',
                            style: TextStyle(fontSize: 10, color: tokens.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: tokens.softSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
                      ),
                      child: Text(
                        hasBudget ? 'Ubah' : 'Atur',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
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
                              Container(height: 6, color: tokens.softSurface),
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

// ─── Month navigation button (banner) ────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.onTap});

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
          border: Border.all(color: tokens.headerBorder),
        ),
        child: Icon(icon, size: 16, color: tokens.headerFg),
      ),
    );
  }
}
