import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isFabExpanded = true;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final expanded = _scrollCtrl.offset < 40;
      if (expanded != _isFabExpanded) setState(() => _isFabExpanded = expanded);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = [
        'Januari','Februari','Maret','April','Mei','Juni',
        'Juli','Agustus','September','Oktober','November','Desember'
      ];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) { return s; }
  }

  void _prevMonth(FinanceProvider p) {
    try {
      final parts = p.currentMonth.split('-').map(int.parse).toList();
      int y = parts[0], m = parts[1] - 1;
      if (m == 0) { m = 12; y--; }
      p.changeMonth('$y-${m.toString().padLeft(2, '0')}');
    } catch (_) {}
  }

  void _nextMonth(FinanceProvider p) {
    try {
      final parts = p.currentMonth.split('-').map(int.parse).toList();
      int y = parts[0], m = parts[1] + 1;
      if (m == 13) { m = 1; y++; }
      p.changeMonth('$y-${m.toString().padLeft(2, '0')}');
    } catch (_) {}
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

  void _showAddTx({FinanceTransaction? editTx}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(editTransaction: editTx),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;
    final totals = provider.monthlyTotals;
    final income = totals['income'] ?? 0.0;
    final expense = totals['expense'] ?? 0.0;
    final balance = income - expense;
    final balanceColor = balance >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed;

    final monthlyTxs = provider.transactions
        .where((tx) => tx.date.startsWith(currentMonth))
        .toList();
    final recentTxs = monthlyTxs.take(5).toList();

    // Greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Selamat Pagi ☀️'
        : hour < 17 ? 'Selamat Siang 🌤️'
        : 'Selamat Malam 🌙';

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      // No standard AppBar — replaced by PlumBanner
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ PLUM BANNER ═══════════════════════════════════════════════════
          _DashboardBanner(
            greeting: greeting,
            monthName: _monthName(currentMonth),
            balance: balance,
            income: income,
            expense: expense,
            balanceColor: balanceColor,
            provider: provider,
            onPrev: () => _prevMonth(provider),
            onNext: () => _nextMonth(provider),
          ),

          // ══ SCROLLABLE CONTENT ════════════════════════════════════════════
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.darkPlum))
                : RefreshIndicator(
                    color: AppTheme.darkPlum,
                    onRefresh: provider.refreshAll,
                    child: ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Quick stats row
                        _QuickStatsRow(txCount: monthlyTxs.length),
                        const SizedBox(height: 28),

                        // Section header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transaksi Terbaru',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (monthlyTxs.length > 5)
                              Text(
                                'Lihat Semua →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkPlum,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Transactions
                        recentTxs.isEmpty
                            ? _EmptyState(onAdd: _showAddTx)
                            : Column(
                                children: recentTxs.map((tx) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _TxCard(
                                    tx: tx,
                                    provider: provider,
                                    getIcon: _icon,
                                    parseColor: _color,
                                    onTap: () => _showAddTx(editTx: tx),
                                  ),
                                )).toList(),
                              ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isFabExpanded
            ? FloatingActionButton.extended(
                key: const ValueKey('fab-ext'),
                backgroundColor: AppTheme.darkPlum,
                foregroundColor: AppTheme.warmCream,
                elevation: 4,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: _showAddTx,
              )
            : FloatingActionButton(
                key: const ValueKey('fab-min'),
                backgroundColor: AppTheme.darkPlum,
                foregroundColor: AppTheme.warmCream,
                elevation: 4,
                shape: const CircleBorder(),
                onPressed: _showAddTx,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
      ),
    );
  }
}

// ─── Dashboard Plum Banner ────────────────────────────────────────────────────
class _DashboardBanner extends StatelessWidget {
  final String greeting, monthName;
  final double balance, income, expense;
  final Color balanceColor;
  final FinanceProvider provider;
  final VoidCallback onPrev, onNext;

  const _DashboardBanner({
    required this.greeting,
    required this.monthName,
    required this.balance,
    required this.income,
    required this.expense,
    required this.balanceColor,
    required this.provider,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkPlum,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -24, top: -36,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              right: 50, top: 30,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: greeting + avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedDarkLavender,
                            ),
                          ),
                          const Text(
                            'TakaraNoto',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warmCream,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Hero Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month navigator inside card
                        Row(
                          children: [
                            _NavBtn(onTap: onPrev, icon: Icons.chevron_left),
                            const SizedBox(width: 8),
                            Text(
                              monthName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedDarkLavender,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NavBtn(onTap: onNext, icon: Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Balance label + value
                        const Text(
                          'Saldo Bersih',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedDarkLavender,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            provider.formatCurrency(balance),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: balanceColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Income / Expense row
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Pemasukan',
                                value: provider.formatCurrency(income),
                                icon: Icons.arrow_downward_rounded,
                                color: AppTheme.emeraldGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStat(
                                label: 'Pengeluaran',
                                value: provider.formatCurrency(expense),
                                icon: Icons.arrow_upward_rounded,
                                color: AppTheme.roseRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Stats Row ──────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final int txCount;
  const _QuickStatsRow({required this.txCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickChip(icon: Icons.receipt_rounded, label: 'Transaksi', value: '$txCount kali'),
        const SizedBox(width: 12),
        _QuickChip(icon: Icons.calendar_month_rounded, label: 'Bulan Ini', value: 'Aktif'),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _QuickChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHeroLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.mutedLightPlum),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.mutedLightPlum, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Card ─────────────────────────────────────────────────────────
class _TxCard extends StatelessWidget {
  final FinanceTransaction tx;
  final FinanceProvider provider;
  final IconData Function(String) getIcon;
  final Color Function(String) parseColor;
  final VoidCallback onTap;

  const _TxCard({
    required this.tx, required this.provider,
    required this.getIcon, required this.parseColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = parseColor(tx.categoryColor ?? '#95a5a6');
    final txColor = tx.type == 'income' ? AppTheme.emeraldGreen : AppTheme.roseRed;
    final sign = tx.type == 'income' ? '+' : '-';

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: catColor),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)],
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: catColor,
                            child: Icon(getIcon(tx.categoryIcon ?? 'ellipsis'), color: Colors.white, size: 19),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.categoryName ?? 'Tanpa Kategori',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
                              if (tx.note.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(tx.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum)),
                              ],
                              const SizedBox(height: 2),
                              Text(tx.date, style: const TextStyle(fontSize: 11, color: AppTheme.mutedLightPlum)),
                            ],
                          ),
                        ),
                        Text(
                          '$sign ${provider.formatCurrency(tx.amount)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: txColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHeroLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.mutedLightPlum),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada transaksi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
            const SizedBox(height: 6),
            const Text(
              'Mulai catat pemasukan dan pengeluaran\nkeuangan Anda di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkPlum,
                foregroundColor: AppTheme.warmCream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Catat Sekarang', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
