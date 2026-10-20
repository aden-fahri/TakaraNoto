import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/mode_switch_button.dart';
import '../widgets/notched_card.dart';
import 'topup_screen.dart';
import 'monthly_balance_screen.dart';
import 'theme_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

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
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;
    final totals = provider.monthlyTotals;
    final income = totals['income'] ?? 0.0;
    final expense = totals['expense'] ?? 0.0;
    final balance = income - expense;
    final balanceColor = balance >= 0 ? tokens.incomeOnHeader : tokens.expenseOnHeader;

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
      backgroundColor: tokens.pageBg,
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
            onBalanceTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyBalanceScreen())),
          ),

          // ══ SCROLLABLE CONTENT ════════════════════════════════════════════
          Expanded(
            child: provider.isLoading
                ? Center(child: CircularProgressIndicator(color: tokens.accent))
                : RefreshIndicator(
                    color: tokens.accent,
                    onRefresh: provider.refreshAll,
                    child: ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (provider.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(provider.error!,
                                style: TextStyle(color: tokens.expense)),
                          ),
                        // Quick stats row
                        _QuickStatsRow(txCount: monthlyTxs.length),
                        const SizedBox(height: 16),

                        // E-Wallet shortcut card
                        _EWalletCard(
                          balance: provider.topupBalance,
                          provider: provider,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopupScreen())),
                        ),
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
                              GestureDetector(
                                onTap: widget.onSeeAll,
                                child: Text(
                                  'Lihat Semua →',
                                  style: TextStyle(
                                    fontSize: AppText.body,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.accent,
                                  ),
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
                heroTag: null,
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                elevation: 4,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.subtitle)),
                onPressed: _showAddTx,
              )
            : FloatingActionButton(
                key: const ValueKey('fab-min'),
                heroTag: null,
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
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
  final VoidCallback onPrev, onNext, onBalanceTap;

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
    required this.onBalanceTap,
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
            // Decorative circles (enlarged & more pronounced)
            Positioned(
              right: -45, top: -45,
              child: Container(
                width: 210, height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.headerFg.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 65, top: 35,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.headerFg.withValues(alpha: 0.06),
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
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppText.bodyLarge,
                                fontWeight: FontWeight.w500,
                                color: tokens.headerMuted,
                              ),
                            ),
                            Text(
                              'TakaraNoto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppText.headline,
                                fontWeight: FontWeight.w800,
                                color: tokens.headerFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ModeSwitchButton(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ThemeSettingsScreen(),
                              ),
                            ),
                            child: Tooltip(
                              message: 'Pengaturan tema',
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: tokens.headerSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: tokens.headerBorder, width: 1),
                                ),
                                child: Icon(Icons.palette_rounded, color: tokens.headerFg, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Logo with prominent glowing circular frame
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.headerFg.withValues(alpha: 0.15),
                              border: Border.all(
                                color: tokens.headerFg.withValues(alpha: 0.45),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Hero Wallet Card (notch step di sudut kanan atas)
                  NotchedCard(
                    color: tokens.headerSurface,
                    borderColor: tokens.headerBorder.withValues(alpha: 0.6),
                    borderWidth: 1.2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shadowBlur: 14,
                    shadowOffset: const Offset(0, 4),
                    child: Stack(
                      children: [
                        // Isi Utama Card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 38, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Label Dompet & Navigasi Bulan
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.wallet_rounded,
                                        size: 16,
                                        color: tokens.headerFg.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DOMPET UTAMA',
                                        style: TextStyle(
                                          fontSize: AppText.label,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                          color: tokens.headerFg.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Navigasi Bulan
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.headerFg.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: tokens.headerBorder.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: 'Bulan sebelumnya',
                                          child: GestureDetector(
                                            onTap: onPrev,
                                            child: Icon(Icons.chevron_left_rounded, size: 16, color: tokens.headerFg),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          monthName,
                                          style: TextStyle(
                                            fontSize: AppText.micro,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.headerFg,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Tooltip(
                                          message: 'Bulan berikutnya',
                                          child: GestureDetector(
                                            onTap: onNext,
                                            child: Icon(Icons.chevron_right_rounded, size: 16, color: tokens.headerFg),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Saldo Bulan Ini (Ukuran Besar & Menonjol)
                              GestureDetector(
                                onTap: onBalanceTap,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Saldo Bulan Ini',
                                          style: TextStyle(
                                            fontSize: AppText.body,
                                            fontWeight: FontWeight.w500,
                                            color: tokens.headerMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 9,
                                          color: tokens.headerMuted,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        provider.formatCurrency(balance),
                                        style: TextStyle(
                                          fontSize: AppText.stat,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: tokens.headerFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Uang Riil (Akumulasi Bulan Lalu + Bulan Ini)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: tokens.headerFg.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: tokens.headerBorder.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 13,
                                      color: tokens.headerFg,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Uang Riil (Bulan Lalu + Ini): ',
                                      style: TextStyle(
                                        fontSize: AppText.label,
                                        color: tokens.headerMuted,
                                      ),
                                    ),
                                    Text(
                                      provider.formatCurrency(provider.cumulativeBalance),
                                      style: TextStyle(
                                        fontSize: AppText.body,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.headerFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Pemasukan & Pengeluaran Row
                              Row(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.south_west_rounded, size: 13, color: tokens.incomeOnHeader),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.formatCurrency(income),
                                        style: TextStyle(
                                          fontSize: AppText.body,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.incomeOnHeader,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Row(
                                    children: [
                                      Icon(Icons.north_east_rounded, size: 13, color: tokens.expenseOnHeader),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.formatCurrency(expense),
                                        style: TextStyle(
                                          fontSize: AppText.body,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.expenseOnHeader,
                                        ),
                                      ),
                                    ],
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
          ],
        ),
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
    final tokens = context.tokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.softSurface,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          border: Border.all(color: tokens.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tokens.textMuted),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: AppText.micro, color: tokens.textMuted, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: AppText.subtitle, color: tokens.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── E-Wallet Card ─────────────────────────────────────────────────────────────
class _EWalletCard extends StatelessWidget {
  final double balance;
  final FinanceProvider provider;
  final VoidCallback onTap;
  const _EWalletCard({required this.balance, required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cardBg = tokens.card;
    final borderCol = tokens.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3f51b5), Color(0xFF5c6bc0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3f51b5).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dompet E-Wallet',
                    style: TextStyle(
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w500,
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.formatCurrency(balance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.title,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3f51b5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
              child: const Row(
                children: [
                  Text('Kelola', style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700, color: Color(0xFF3f51b5))),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF3f51b5)),
                ],
              ),
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
    final tokens = context.tokens;
    const transferColor = Color(0xFF3f51b5);
    final isTransfer = tx.isTransfer;
    final catColor = isTransfer ? transferColor : parseColor(tx.categoryColor ?? '#95a5a6');
    final txColor = isTransfer
        ? transferColor
        : tx.type == 'income'
            ? tokens.income
            : tokens.expense;
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
                            child: Icon(
                              isTransfer ? Icons.swap_horiz_rounded : getIcon(tx.categoryIcon ?? 'ellipsis'),
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.displayName,
                                  style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                              if (tx.note.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(tx.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: AppText.body, color: tokens.textMuted)),
                              ],
                              const SizedBox(height: 2),
                              Text(tx.date, style: TextStyle(fontSize: AppText.label, color: tokens.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          '$sign ${provider.formatCurrency(tx.amount)}',
                          style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: txColor),
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
    final tokens = context.tokens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: tokens.softSurface,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border),
              ),
              child: Icon(Icons.receipt_long_outlined, size: 32, color: tokens.textMuted),
            ),
            const SizedBox(height: 16),
            Text('Belum ada transaksi',
                style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Mulai catat pemasukan dan pengeluaran\nkeuangan Anda di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.body, color: tokens.textMuted, height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Catat Sekarang', style: TextStyle(fontSize: AppText.bodyLarge, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
