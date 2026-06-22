import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filterType = 'all';
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

  double _dailyNet(List<FinanceTransaction> txs) =>
      txs.fold(0.0, (acc, tx) => tx.type == 'income' ? acc + tx.amount : acc - tx.amount);

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
    provider.deleteTx(tx.id!);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi "${tx.categoryName ?? 'ini'}" dihapus'),
        action: SnackBarAction(
          label: 'Batalkan',
          textColor: AppTheme.amberAccent,
          onPressed: () {
            // Re-add with same data
            provider.addTx(
              categoryId: tx.categoryId,
              amount: tx.amount,
              type: tx.type,
              date: tx.date,
              note: tx.note,
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;

    // Filter
    final filtered = provider.transactions.where((tx) {
      final inMonth = tx.date.startsWith(currentMonth);
      final q = _searchQuery.toLowerCase();
      final matchSearch = tx.note.toLowerCase().contains(q) ||
          (tx.categoryName ?? '').toLowerCase().contains(q);
      final matchType = _filterType == 'all' || tx.type == _filterType;
      return inMonth && matchSearch && matchType;
    }).toList();

    // Compute totals for this month/filter
    final double monthIncome = filtered.fold(0.0, (acc, tx) => tx.type == 'income' ? acc + tx.amount : acc);
    final double monthExpense = filtered.fold(0.0, (acc, tx) => tx.type == 'expense' ? acc + tx.amount : acc);

    // Group by date
    final Map<String, List<FinanceTransaction>> grouped = {};
    for (final tx in filtered) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
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
                  activeColor: AppTheme.emeraldGreen,
                  onTap: () => setState(() => _filterType = 'income'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pengeluaran', icon: Icons.arrow_upward_rounded,
                  isActive: _filterType == 'expense',
                  activeColor: AppTheme.roseRed,
                  onTap: () => setState(() => _filterType = 'expense'),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: AppTheme.borderLight, margin: const EdgeInsets.only(top: 8)),

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
                      final netColor = net >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed;

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
                                    color: AppTheme.surfaceHeroLight,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Text(
                                    _formatDate(date),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkPlum),
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
                            final catColor = _color(tx.categoryColor ?? '#999999');
                            final isIncome = tx.type == 'income';
                            return Dismissible(
                              key: Key('tx_${tx.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppTheme.roseRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_rounded, color: AppTheme.roseRed),
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.borderLight, width: 1),
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
                                        child: Icon(_icon(tx.categoryIcon ?? ''), color: catColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.categoryName ?? 'Kategori',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.darkPlum,
                                              ),
                                            ),
                                            if (tx.note.isNotEmpty)
                                              Text(
                                                tx.note,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.mutedLightPlum,
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
                                          color: isIncome ? AppTheme.emeraldGreen : AppTheme.roseRed,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHeroLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Icon(Icons.search_off_rounded, size: 32, color: AppTheme.mutedLightPlum),
          ),
          const SizedBox(height: 16),
          const Text('Tidak ada transaksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.darkPlum)),
          const SizedBox(height: 6),
          const Text('Coba ubah filter atau kata kunci pencarian',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum)),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row + month navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Riwayat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.warmCream),
                  ),
                  // Month navigator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavBtn(onTap: onPrev, icon: Icons.chevron_left),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            monthName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedDarkLavender,
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
                    color: AppTheme.emeraldGreen,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Keluar',
                    value: provider.formatCurrency(expense),
                    color: AppTheme.roseRed,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search bar inside banner
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search_rounded, color: AppTheme.mutedDarkLavender, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(fontSize: 14, color: AppTheme.warmCream),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cari transaksi...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppTheme.mutedDarkLavender.withValues(alpha: 0.7),
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
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.close_rounded, size: 18, color: AppTheme.mutedDarkLavender),
                        ),
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
    final ac = activeColor ?? AppTheme.darkPlum;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? ac.withValues(alpha: 0.1) : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? ac : AppTheme.borderLight,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isActive ? ac : AppTheme.mutedLightPlum),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? ac : AppTheme.mutedLightPlum,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
