import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/app_header.dart';
import '../widgets/list_row.dart';
import '../widgets/notched_card.dart';
import '../widgets/palette_sheet.dart';
import '../widgets/sheet_scaffold.dart';
import 'monthly_balance_screen.dart';
import 'topup_screen.dart';

/// Ukuran judul kartu (`.h2` di mockup: 15/600).
const double _h2 = 15;

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _dateLabel(String iso) {
  try {
    final p = iso.split('-');
    return '${int.parse(p[2])} ${_shortMonths[int.parse(p[1]) - 1]} ${p[0]}';
  } catch (_) {
    return iso;
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _monthChipLabel(String monthYear) {
    try {
      final p = monthYear.split('-');
      return '${_shortMonths[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) {
      return monthYear;
    }
  }

  /// Ringkas tanpa pemisah ribuan: mockup memakai `Rp 364rb` dan `Rp 477 rb`.
  String _compact(double v, {bool spaceBeforeSuffix = false}) {
    final abs = v.abs();
    final sign = v < 0 ? '- ' : '';
    if (abs < 1000) return '${sign}Rp ${abs.round()}';
    final suffix = spaceBeforeSuffix ? ' rb' : 'rb';
    return '${sign}Rp ${(abs / 1000).round()}$suffix';
  }

  void _showAddTx({FinanceTransaction? editTx}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(editTransaction: editTx),
    );
  }

  void _openBalance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MonthlyBalanceScreen()),
    );
  }

  void _openTopup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopupScreen()),
    );
  }

  /// Lembar pilih bulan (pengganti panah prev/next lama; mockup hanya
  /// menampilkan chip dengan chevron).
  ///
  /// Daftar tahun dibangun dari data: tahun transaksi terlama sampai tahun
  /// depan, sehingga riwayat lama tetap terjangkau.
  List<int> _sheetYears(FinanceProvider provider) {
    final now = DateTime.now().year;
    int? minYear;
    int? maxYear;
    for (final tx in provider.transactions) {
      final y = tx.date.length >= 4
          ? int.tryParse(tx.date.substring(0, 4))
          : null;
      if (y == null) continue;
      minYear = (minYear == null || y < minYear) ? y : minYear;
      maxYear = (maxYear == null || y > maxYear) ? y : maxYear;
    }
    final start = minYear == null || now < minYear ? now : minYear;
    var end = now + 1;
    if (maxYear != null && maxYear > end) end = maxYear;
    return [for (var y = start; y <= end; y++) y];
  }

  void _showMonthSheet(FinanceProvider provider) {
    final t = context.tokens;
    final current = provider.currentMonth;
    final years = _sheetYears(provider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: SheetScaffold(
            title: 'Pilih bulan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final y in years) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      '$y',
                      style: TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w600,
                        color: t.textMuted,
                      ),
                    ),
                  ),
                  for (var m = 1; m <= 12; m++)
                    InkWell(
                      onTap: () {
                        provider.changeMonth(
                          '$y-${m.toString().padLeft(2, '0')}',
                        );
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_shortMonths[m - 1]} $y',
                                style: TextStyle(
                                  fontSize: AppText.bodyLarge,
                                  fontWeight:
                                      current ==
                                          '$y-${m.toString().padLeft(2, '0')}'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color:
                                      current ==
                                          '$y-${m.toString().padLeft(2, '0')}'
                                      ? t.accent
                                      : t.textPrimary,
                                ),
                              ),
                            ),
                            if (current == '$y-${m.toString().padLeft(2, '0')}')
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: t.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<FinanceProvider>(context);
    final currentMonth = provider.currentMonth;
    final totals = provider.monthlyTotals;
    final income = totals['income'] ?? 0.0;
    final expense = totals['expense'] ?? 0.0;
    final flow = income - expense;

    final monthlyTxs = provider.transactions
        .where((tx) => tx.date.startsWith(currentMonth))
        .toList();
    final recentTxs = monthlyTxs.take(5).toList();
    final isEmpty = monthlyTxs.isEmpty;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Selamat pagi'
        : hour < 17
        ? 'Selamat siang'
        : 'Selamat malam';
    final greetingIcon = isDark || hour >= 17
        ? Icons.nightlight_round
        : Icons.wb_sunny_rounded;

    return Scaffold(
      backgroundColor: t.pageBg,
      body: Stack(
        children: [
          // ── Header (tinggi 172, kartu saldo menimpa) ────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppHeader(
              height: 172,
              title: 'TakaraNoto',
              onPaletteTap: () => showPaletteSheet(context),
              topRow: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(greetingIcon, size: 14, color: t.persik),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        greeting,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w500,
                          color: t.headerMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Konten: mulai di top 96, terpotong di batas itu ─────────────────
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: provider.isLoading
                  ? Center(child: CircularProgressIndicator(color: t.accent))
                  : RefreshIndicator(
                      color: t.accent,
                      onRefresh: provider.refreshAll,
                      child: ListView(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: [
                          if (provider.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                provider.error!,
                                style: TextStyle(color: t.expense),
                              ),
                            ),
                          _BalanceCard(
                            monthLabel: _monthChipLabel(currentMonth),
                            onMonthTap: () => _showMonthSheet(provider),
                            balance: provider.cumulativeBalance,
                            income: income,
                            expense: expense,
                            flow: flow,
                            isDark: isDark,
                            balanceText: provider.formatCurrency(
                              provider.cumulativeBalance,
                            ),
                            incomeText: _compact(income),
                            expenseText: _compact(expense),
                            flowText:
                                '${flow >= 0 ? '+' : '-'} ${provider.formatCurrency(flow.abs())}',
                            onBalanceTap: _openBalance,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _WalletTile(
                                label: 'Dompet utama',
                                value: _compact(
                                  provider.cumulativeBalance,
                                  spaceBeforeSuffix: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _WalletTile(
                                label: 'E-Wallet',
                                value: _compact(
                                  provider.topupBalance,
                                  spaceBeforeSuffix: true,
                                ),
                                onTap: _openTopup,
                              ),
                              const SizedBox(width: 10),
                              _WalletTile(
                                label: 'Tabungan',
                                value: _compact(
                                  provider.totalSaved,
                                  spaceBeforeSuffix: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isEmpty)
                            _EmptyCard(onAdd: () => _showAddTx())
                          else
                            _RecentCard(
                              txs: recentTxs,
                              provider: provider,
                              onSeeAll: widget.onSeeAll,
                              onRowTap: (tx) => _showAddTx(editTx: tx),
                            ),
                        ],
                      ),
                    ),
            ),
          ),

          // ── FAB (mockup: kanan 16, atas 92 dari dasar = 16 di atas navbar) ──
          if (!isEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: Material(
                color: t.accent,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  onTap: () => _showAddTx(),
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    key: const ValueKey('home-fab'),
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: t.onAccent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Tambah Transaksi',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: AppText.subtitle,
                                fontWeight: FontWeight.w600,
                                color: t.onAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Kartu saldo bertakik ─────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.monthLabel,
    required this.onMonthTap,
    required this.balance,
    required this.income,
    required this.expense,
    required this.flow,
    required this.isDark,
    required this.balanceText,
    required this.incomeText,
    required this.expenseText,
    required this.flowText,
    required this.onBalanceTap,
  });

  final String monthLabel;
  final VoidCallback onMonthTap;
  final double balance, income, expense, flow;
  final bool isDark;
  final String balanceText, incomeText, expenseText, flowText;
  final VoidCallback onBalanceTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Mockup memakai 8% pada tema terang dan 10% pada tema gelap.
    final boxAlpha = isDark ? 0.10 : 0.08;
    final ruleAlpha = isDark ? 0.20 : 0.18;

    return NotchedCard(
      color: t.persik,
      borderColor: null,
      borderWidth: 0,
      child: SizedBox(
        height: 214,
        child: Stack(
          children: [
            // Chip bulan di dalam takik (kanan 10, atas 6, tinggi 32)
            Positioned(
              right: 10,
              top: 6,
              child: GestureDetector(
                onTap: onMonthTap,
                child: Container(
                  key: const ValueKey('home-month-chip'),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.chip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Label + saldo (kiri 20, atas 18)
            Positioned(
              left: 20,
              right: 20,
              top: 18,
              child: GestureDetector(
                onTap: onBalanceTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo keuangan',
                      style: TextStyle(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w500,
                        color: t.onPersik.withValues(alpha: 0.8),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        balanceText,
                        style: TextStyle(
                          fontSize: AppText.stat,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: t.onPersik,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dua kotak pemasukan/pengeluaran (kiri-kanan 20, atas 92)
            Positioned(
              left: 20,
              right: 20,
              top: 92,
              child: Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Pemasukan',
                      value: incomeText,
                      hasValue: income != 0,
                      icon: Icons.north_east_rounded,
                      valueColor: t.incomeOnPersik,
                      backgroundColor: t.onPersik.withValues(alpha: boxAlpha),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Pengeluaran',
                      value: expenseText,
                      hasValue: expense != 0,
                      icon: Icons.south_west_rounded,
                      valueColor: t.expenseOnPersik,
                      backgroundColor: t.onPersik.withValues(alpha: boxAlpha),
                    ),
                  ),
                ],
              ),
            ),

            // Ringkasan arus kas (kiri-kanan 20, atas 164, tinggi 36)
            Positioned(
              left: 20,
              right: 20,
              top: 164,
              height: 36,
              child: Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: t.onPersik.withValues(alpha: ruleAlpha),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'Arus kas bulan ini',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppText.body,
                            fontWeight: FontWeight.w500,
                            color: t.onPersik,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          flow == 0
                              ? flowText.replaceFirst(RegExp(r'^\+ |^- '), '')
                              : flowText,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppText.label + 2,
                            fontWeight: FontWeight.w600,
                            color: flow == 0
                                ? t.onPersik
                                : flow >= 0
                                ? t.incomeOnPersik
                                : t.expenseOnPersik,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.hasValue,
    required this.icon,
    required this.valueColor,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final bool hasValue;
  final IconData icon;
  final Color valueColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasValue) ...[
                Icon(icon, size: 12, color: valueColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w500,
                      color: t.onPersik,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w600,
                color: hasValue ? valueColor : t.onPersik,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile dompet ──────────────────────────────────────────────────────────────
class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: AppText.body, color: t.textMuted),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
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

// ─── Kartu transaksi terbaru ──────────────────────────────────────────────────
class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.txs,
    required this.provider,
    required this.onSeeAll,
    required this.onRowTap,
  });

  final List<FinanceTransaction> txs;
  final FinanceProvider provider;
  final VoidCallback? onSeeAll;
  final ValueChanged<FinanceTransaction> onRowTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Transaksi terbaru',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: _h2,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'Lihat semua',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < txs.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.border),
            _TxRow(
              tx: txs[i],
              provider: provider,
              onTap: () => onRowTap(txs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.provider, required this.onTap});

  final FinanceTransaction tx;
  final FinanceProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isTransfer = tx.isTransfer;
    final color = isTransfer
        ? t.transfer
        : tx.type == 'income'
        ? t.income
        : t.expense;
    final sign = tx.type == 'income' ? '+' : '-';
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : tx.type == 'income'
        ? Icons.north_east_rounded
        : Icons.south_west_rounded;

    return ListRow(
      icon: icon,
      iconColor: color,
      title: tx.note.isNotEmpty ? tx.note : tx.displayName,
      subtitle: _dateLabel(tx.date),
      amount: '$sign ${provider.formatCurrency(tx.amount)}',
      amountColor: color,
      onTap: onTap,
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.softSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: t.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada transaksi bulan ini',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _h2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Catat pemasukan atau pengeluaran pertama Anda. Saldo dan dompet akan terisi otomatis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.body,
              color: t.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.onAccent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: t.onAccent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tambah transaksi pertama',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w600,
                          color: t.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
