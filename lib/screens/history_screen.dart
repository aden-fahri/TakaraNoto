import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/decorative_header_circles.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filterType = 'all';
  int? _filterCatId;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  String _dayName(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const days = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
      return days[d.weekday % 7];
    } catch (_) { return ''; }
  }

  String _formatDate(String dateStr) {
    try {
      final p = dateStr.split('-');
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
      return '${_dayName(dateStr)}, ${int.parse(p[2])} ${months[int.parse(p[1]) - 1]}';
    } catch (_) { return dateStr; }
  }

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = ['Januari','Februari','Maret','April','Mei','Juni',
          'Juli','Agustus','September','Oktober','November','Desember'];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) { return s; }
  }

  double _dailyNet(List<FinanceTransaction> txs) => txs
      .where((tx) => !tx.isTransfer)
      .fold(0.0, (acc, tx) => tx.type == 'income' ? acc + tx.amount : acc - tx.amount);

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

  void _showEdit(FinanceTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(editTransaction: tx),
    );
  }

  void _deleteWithUndo(FinanceProvider provider, FinanceTransaction tx) {
    if (tx.isTransfer) {
      _confirmDeleteTransfer(provider, tx);
      return;
    }
    provider.deleteTx(tx.id!);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi "${tx.categoryName ?? 'ini'}" dihapus'),
        action: SnackBarAction(
          label: 'Batalkan',
          textColor: context.tokens.warning,
          onPressed: () {
            // Re-add with same data
            provider.addTx(
              categoryId: tx.categoryId,
              amount: tx.amount,
              type: tx.type,
              date: tx.date,
              note: tx.note,
              savingsGoalId: tx.savingsGoalId,
              walletType: tx.walletType,
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _confirmDeleteTransfer(FinanceProvider provider, FinanceTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transfer'),
        content: const Text(
            'Transfer ini tercatat di kedua dompet (dompet utama & e-wallet). Menghapus akan menghapus keduanya. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteTx(tx.id!);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfer dihapus')),
              );
            },
            child: Text('Hapus', style: TextStyle(color: context.tokens.expense)),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;

    // Filter
    final filtered = provider.transactions.where((tx) {
      final inMonth = tx.date.startsWith(currentMonth);
      final q = _searchQuery.toLowerCase();
      final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
      final matchText = tx.note.toLowerCase().contains(q) ||
          tx.displayName.toLowerCase().contains(q);
      final matchAmount = digits.isNotEmpty &&
          tx.amount.round().toString().contains(digits);
      final matchSearch = q.isEmpty || matchText || matchAmount;
      final matchType = _filterType == 'all' || tx.type == _filterType;
      final matchCategory = _filterCatId == null || tx.categoryId == _filterCatId;
      return inMonth && matchSearch && matchType && matchCategory;
    }).toList();

    // Compute totals for this month/filter. Transfers and savings flows are
    // excluded from income/expense; savings are reported separately (see the
    // Stats screen's "Ditabung Bersih" row).
    final double monthIncome = filtered
        .where((tx) => !tx.isTransfer && !tx.categoryIsSavings && tx.type == 'income')
        .fold(0.0, (acc, tx) => acc + tx.amount);
    final double monthExpense = filtered
        .where((tx) => !tx.isTransfer && !tx.categoryIsSavings && tx.type == 'expense')
        .fold(0.0, (acc, tx) => acc + tx.amount);

    // Group by date
    final Map<String, List<FinanceTransaction>> grouped = {};
    for (final tx in filtered) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: tokens.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ PLUM BANNER ═══════════════════════════════════════════════════
          _HistoryBanner(
            monthName: _monthName(currentMonth),
            searchCtrl: _searchCtrl,
            searchQuery: _searchQuery,
            onSearch: (v) => setState(() => _searchQuery = v),
            onClear: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
            onPrev: () {
              HapticFeedback.lightImpact();
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
              try {
                final p = currentMonth.split('-').map(int.parse).toList();
                int y = p[0], m = p[1] - 1;
                if (m == 0) { m = 12; y--; }
                provider.changeMonth('$y-${m.toString().padLeft(2, '0')}');
              } catch (_) {}
            },
            onNext: () {
              HapticFeedback.lightImpact();
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
              try {
                final p = currentMonth.split('-').map(int.parse).toList();
                int y = p[0], m = p[1] + 1;
                if (m == 13) { m = 1; y++; }
                provider.changeMonth('$y-${m.toString().padLeft(2, '0')}');
              } catch (_) {}
            },
            income: monthIncome,
            expense: monthExpense,
            provider: provider,
          ),

          // ══ FILTER CHIPS ══════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua', icon: Icons.apps_rounded,
                  isActive: _filterType == 'all',
                  onTap: () => setState(() => _filterType = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pemasukan', icon: Icons.arrow_downward_rounded,
                  isActive: _filterType == 'income',
                  activeColor: tokens.income,
                  onTap: () => setState(() => _filterType = 'income'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pengeluaran', icon: Icons.arrow_upward_rounded,
                  isActive: _filterType == 'expense',
                  activeColor: tokens.expense,
                  onTap: () => setState(() => _filterType = 'expense'),
                ),
              ],
            ),
          ),
          // ══ CATEGORY FILTER CHIPS ═════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CatChip(
                    label: 'Semua Kategori',
                    active: _filterCatId == null,
                    color: tokens.accent,
                    onTap: () => setState(() => _filterCatId = null),
                  ),
                  ...provider.categories.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _CatChip(
                          label: c.name,
                          active: _filterCatId == c.id,
                          color: _color(c.color),
                          onTap: () => setState(() =>
                              _filterCatId = _filterCatId == c.id ? null : c.id),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Container(height: 0.5, color: tokens.border, margin: const EdgeInsets.only(top: 8)),

          // ══ LIST ══════════════════════════════════════════════════════════
          Expanded(
            child: sortedDates.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: sortedDates.length,
                    itemBuilder: (ctx, i) {
                      final date = sortedDates[i];
                      final dayTxs = grouped[date]!;
                      final net = _dailyNet(dayTxs);
                      final netColor = net >= 0 ? tokens.income : tokens.expense;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header pills
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tokens.softSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: tokens.border),
                                  ),
                                  child: Text(
                                    _formatDate(date),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: netColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: netColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    '${net >= 0 ? '+' : ''}${Provider.of<FinanceProvider>(context, listen: false).formatCurrency(net)}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: netColor),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Transactions in this day
                          ...dayTxs.map((tx) {
                            const transferColor = Color(0xFF3f51b5);
                            final isTransfer = tx.isTransfer;
                            final catColor = isTransfer
                                ? transferColor
                                : _color(tx.categoryColor ?? '#999999');
                            final isIncome = tx.type == 'income';
                            return Dismissible(
                              key: Key('tx_${tx.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: tokens.expense.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.delete_rounded, color: tokens.expense),
                              ),
                              confirmDismiss: (_) async {
                                _deleteWithUndo(provider, tx);
                                return false; // don't auto-remove; let provider rebuild
                              },
                              child: GestureDetector(
                                onTap: () => _showEdit(tx),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: tokens.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: tokens.border, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      // Category icon
                                      Container(
                                        width: 42, height: 42,
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isTransfer ? Icons.swap_horiz_rounded : _icon(tx.categoryIcon ?? ''),
                                          color: catColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.displayName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.textPrimary,
                                              ),
                                            ),
                                            if (tx.note.isNotEmpty)
                                              Text(
                                                tx.note,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: tokens.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Amount
                                      Text(
                                        '${isIncome ? '+' : '-'}${provider.formatCurrency(tx.amount)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isTransfer
                                              ? transferColor
                                              : isIncome
                                                  ? tokens.income
                                                  : tokens.expense,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final tokens = context.tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: tokens.softSurface,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.border),
            ),
            child: Icon(Icons.search_off_rounded, size: 32, color: tokens.textMuted),
          ),
          const SizedBox(height: 16),
          Text('Tidak ada transaksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 6),
          Text('Coba ubah filter atau kata kunci pencarian',
              style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        ],
      ),
    );
  }
}

// ─── History Plum Banner ──────────────────────────────────────────────────────
class _HistoryBanner extends StatelessWidget {
  final String monthName;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double income;
  final double expense;
  final FinanceProvider provider;

  const _HistoryBanner({
    required this.monthName,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearch,
    required this.onClear,
    required this.onPrev,
    required this.onNext,
    required this.income,
    required this.expense,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Title row + month navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Riwayat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.headerFg),
                  ),
                  // Month navigator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.headerSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.headerBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavBtn(onTap: onPrev, icon: Icons.chevron_left),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            monthName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.headerMuted,
                            ),
                          ),
                        ),
                        _NavBtn(onTap: onNext, icon: Icons.chevron_right),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Monthly totals summary row
              Row(
                children: [
                  _MiniStat(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Masuk',
                    value: provider.formatCurrency(income),
                    color: tokens.incomeOnHeader,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Keluar',
                    value: provider.formatCurrency(expense),
                    color: tokens.expenseOnHeader,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search bar inside banner
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.headerSurface,
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  border: Border.all(color: tokens.headerBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: tokens.headerMuted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        style: TextStyle(fontSize: 14, color: tokens.headerFg),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cari transaksi...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: tokens.headerMuted.withValues(alpha: 0.7),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: onSearch,
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: onClear,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(Icons.close_rounded, size: 18, color: tokens.headerMuted),
                        ),
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

// ─── Mini stat tile inside banner ─────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
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

// ─── Category Filter Chip ─────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : tokens.card,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          border: Border.all(
            color: active ? color : tokens.border,
            width: active ? 1.3 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? color : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label, required this.icon,
    required this.isActive, this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ac = activeColor ?? tokens.accent;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? ac.withValues(alpha: 0.1) : tokens.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? ac : tokens.border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isActive ? ac : tokens.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? ac : tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
