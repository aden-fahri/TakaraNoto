import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

class BudgetModal extends StatefulWidget {
  final Category category;
  final double currentLimit;

  const BudgetModal({
    super.key,
    required this.category,
    required this.currentLimit,
  });

  @override
  State<BudgetModal> createState() => _BudgetModalState();
}

class _BudgetModalState extends State<BudgetModal> {
  final _limitCtrl = TextEditingController();
  String _budgetType = 'goal';
  bool _prefilledFromPrevious = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final existingBudget = provider.budgets.any((b) => b.categoryId == widget.category.id)
        ? provider.budgets.firstWhere((b) => b.categoryId == widget.category.id)
        : null;
    if (existingBudget != null) {
      _budgetType = existingBudget.budgetType;
      _limitCtrl.text = NumberFormat.decimalPattern('id').format(existingBudget.limitAmount);
    } else if (widget.currentLimit > 0) {
      _limitCtrl.text = NumberFormat.decimalPattern('id').format(widget.currentLimit);
    } else {
      _loadPreviousBudget(provider);
    }
  }

  Future<void> _loadPreviousBudget(FinanceProvider provider) async {
    final prev = await provider.getPreviousMonthBudget(widget.category.id!);
    if (prev == null || !mounted || prev.limitAmount <= 0) return;
    setState(() {
      _budgetType = prev.budgetType;
      if (_limitCtrl.text.isEmpty) {
        _limitCtrl.text = NumberFormat.decimalPattern('id').format(prev.limitAmount);
        _prefilledFromPrevious = true;
      }
    });
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  void _onLimitChanged(String text) {
    if (text.isEmpty) {
      setState(() {});
      return;
    }
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) { _limitCtrl.text = ''; setState(() {}); return; }
    final formatted = NumberFormat.decimalPattern('id').format(double.parse(clean));
    _limitCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  String? get _monthlyHint {
    if (_budgetType != 'daily_limit') return null;
    final clean = _limitCtrl.text.replaceAll('.', '');
    final val = double.tryParse(clean);
    if (val == null || val <= 0) return null;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    return '≈ ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val * days)}/bulan ($days hari)';
  }

  void _save() {
    final clean = _limitCtrl.text.replaceAll('.', '');
    final limit = double.tryParse(clean);
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid!')),
      );
      return;
    }
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    provider.addOrUpdateBg(
      categoryId: widget.category.id!,
      limitAmount: limit,
      monthYear: provider.currentMonth,
      budgetType: _budgetType,
    );
    Navigator.pop(context);
  }

  void _delete() {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final budget = provider.budgets.firstWhere(
      (b) => b.categoryId == widget.category.id,
      orElse: () => throw Exception('Budget not found'),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anggaran'),
        content: const Text('Hapus batas anggaran untuk kategori ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              provider.deleteBg(budget.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Hapus', style: TextStyle(color: ctx.tokens.expense)),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
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

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final catColor = _parseColor(widget.category.color);
    final borderCol = tokens.border;
    final modalBg = tokens.card;
    final saveBg = tokens.accent;
    final saveFg = tokens.onAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: borderCol,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.softSurface,
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        ),
                        child: Icon(Icons.close_rounded, size: 18,
                            color: tokens.textPrimary),
                      ),
                    ),
                    Text(
                      'Atur Anggaran',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    widget.currentLimit > 0
                        ? GestureDetector(
                            onTap: _delete,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.expense.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                              ),
                              child: Icon(Icons.delete_outline_rounded, size: 18, color: tokens.expense),
                            ),
                          )
                        : const SizedBox(width: 34),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category indicator
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.softSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: catColor,
                              child: Icon(
                                _getIconData(widget.category.icon),
                                color: Colors.white, size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.category.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Batas pengeluaran ${_budgetType == 'goal' ? 'bulanan' : 'harian'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Period toggle
                    Row(
                      children: [
                        Expanded(
                          child: _PeriodBtn(
                            label: 'Bulanan',
                            icon: Icons.calendar_month_rounded,
                            active: _budgetType == 'goal',
                            saveBg: saveBg,
                            saveFg: saveFg,
                            onTap: () => setState(() => _budgetType = 'goal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PeriodBtn(
                            label: 'Harian',
                            icon: Icons.today_rounded,
                            active: _budgetType == 'daily_limit',
                            saveBg: saveBg,
                            saveFg: saveFg,
                            onTap: () => setState(() => _budgetType = 'daily_limit'),
                          ),
                        ),
                      ],
                    ),
                    if (_prefilledFromPrevious) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Disalin dari bulan lalu — sesuaikan bila perlu.',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Amount label
                    Text(
                      'Batas Anggaran ${_budgetType == 'goal' ? 'Bulanan' : 'Harian'} (Rp)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Amount input
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: tokens.textPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Rp',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _limitCtrl,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textMuted.withValues(alpha: 0.4),
                                ),
                              ),
                              onChanged: _onLimitChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_monthlyHint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _monthlyHint!,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saveBg,
                          foregroundColor: saveFg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Simpan Anggaran',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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

// ─── Period toggle button ─────────────────────────────────────────────────────
class _PeriodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color saveBg, saveFg;
  final VoidCallback onTap;

  const _PeriodBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.saveBg,
    required this.saveFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bg = active ? saveBg : tokens.softSurface;
    final fg = active ? saveFg : tokens.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          border: Border.all(
            color: active ? saveBg : tokens.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
