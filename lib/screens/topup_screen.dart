import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';

class TopupScreen extends StatelessWidget {
  const TopupScreen({super.key});

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionModal(walletType: 'topup'),
    );
  }

  void _showEditExpense(BuildContext context, FinanceTransaction tx) {
    // Only allow editing/deleting top-up expenses (walletType = topup)
    // Additions (walletType = main) should be managed from the main dashboard
    if (tx.walletType != 'topup') {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubah atau hapus transaksi pengisian saldo (Top Up) melalui Dashboard utama.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(editTransaction: tx, walletType: 'topup'),
    );
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
      case 'payments': return Icons.payments_rounded;
      case 'download': return Icons.download_rounded;
      case 'ellipsis': return Icons.more_horiz_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  Color _color(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final txs = provider.topupTransactions;
    final balance = provider.topupBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bannerBg = isDark ? AppTheme.deepPlum : AppTheme.darkPlum;
    final cardBg = isDark ? AppTheme.lighterPlum : Colors.white;
    final borderCol = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepPlum : AppTheme.warmCream,
      body: Column(
        children: [
          // ─── PLUM BANNER ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button & Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.warmCream),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Dompet E-Wallet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warmCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Balance Card
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Saldo E-Wallet Saat Ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.mutedDarkLavender,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.stars_rounded, size: 10, color: Color(0xFFFFB300)),
                                    SizedBox(width: 4),
                                    Text('E-Money', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    provider.formatCurrency(balance),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.warmCream,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.warmCream,
                                  foregroundColor: AppTheme.darkPlum,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 2,
                                ),
                                onPressed: () => _showAddExpense(context),
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                label: const Text('Keluar Uang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── TRANSACTION HISTORY LIST ────────────────────────────────────────
          Expanded(
            child: txs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceHeroLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderCol),
                            ),
                            child: const Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.mutedLightPlum),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada transaksi e-wallet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppTheme.warmCream : AppTheme.darkPlum),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gunakan kategori "Top Up" di Dashboard utama untuk mendanai e-wallet Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: txs.length,
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final catColor = _color(tx.categoryColor ?? '#95a5a6');
                      final isAdd = tx.type == 'income'; // Force display as income if it is a topup addition
                      final txColor = isAdd ? AppTheme.emeraldGreen : AppTheme.roseRed;
                      final sign = isAdd ? '+' : '-';

                      return Card(
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _showEditExpense(context, tx),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Category Icon
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: catColor.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: catColor,
                                    child: Icon(_icon(tx.categoryIcon ?? ''), color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.categoryName ?? 'Kategori',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppTheme.warmCream : AppTheme.darkPlum,
                                        ),
                                      ),
                                      if (tx.note.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tx.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.mutedLightPlum),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        tx.date,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.mutedLightPlum),
                                      ),
                                    ],
                                  ),
                                ),

                                // Amount
                                Text(
                                  '$sign ${provider.formatCurrency(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: txColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
