import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/decorative_header_circles.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';
import '../widgets/transaction_form_sheet.dart';

/// Transaksi tab: all group cash movements, filterable, grouped by date.
class TransaksiTab extends StatefulWidget {
  const TransaksiTab({super.key});

  @override
  State<TransaksiTab> createState() => _TransaksiTabState();
}

class _TransaksiTabState extends State<TransaksiTab> {
  TxType? _filter;

  bool _matches(GroupTransaction tx) => _filter == null || tx.type == _filter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: group != null
          ? FloatingActionButton.extended(
              heroTag: 'zainnoto-transaksi-fab',
              onPressed: () => TransactionFormSheet.show(context),
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text(
                'Catat Transaksi Kas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              elevation: 4,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            provider: provider,
            onAdd: () => TransactionFormSheet.show(context),
          ),
          if (provider.isRefreshing)
            LinearProgressIndicator(
              minHeight: 2,
              color: t.accent,
              backgroundColor: Colors.transparent,
            ),
          if (group != null) _FilterRow(
            filter: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          Expanded(
            child: group == null
                ? const _EmptyNotice(
                    icon: Icons.groups_rounded,
                    title: 'Belum Ada Grup',
                    message: 'Buat grup dulu di tab Beranda.',
                  )
                : _TransactionList(provider: provider, matches: _matches),
          ),
        ],
      ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  const _Banner({required this.provider, required this.onAdd});

  final ZainNotoProvider provider;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.headerBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const DecorativeHeaderCircles(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transaksi Kas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.headerFg,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: t.headerSurface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: t.headerBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: t.headerFg),
                              const SizedBox(width: 5),
                              Text(
                                'Catat',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.headerFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _BannerStat(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Kas Masuk',
                          value: formatRupiah(provider.totalIncome),
                          color: t.incomeOnHeader,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BannerStat(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Kas Keluar',
                          value: formatRupiah(provider.totalExpense),
                          color: t.expenseOnHeader,
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
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.headerSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.headerBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: t.headerMuted),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter row ───────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});

  final TxType? filter;
  final ValueChanged<TxType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _FilterChip(
            label: 'Semua',
            selected: filter == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Iuran',
            selected: filter == TxType.dues,
            onTap: () => onChanged(TxType.dues),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Masuk',
            selected: filter == TxType.otherIncome,
            onTap: () => onChanged(TxType.otherIncome),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Keluar',
            selected: filter == TxType.expense,
            onTap: () => onChanged(TxType.expense),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.card,
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(color: t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? t.onAccent : t.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── List ─────────────────────────────────────────────────────────────────────
class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.provider, required this.matches});

  final ZainNotoProvider provider;
  final bool Function(GroupTransaction) matches;

  String _dateHeader(String date) {
    final now = DateTime.now();
    if (date == dateToStr(now)) return 'Hari Ini';
    if (date == dateToStr(now.subtract(const Duration(days: 1)))) {
      return 'Kemarin';
    }
    return formatTanggal(date);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final txs = provider.transactions.where(matches).toList();

    if (txs.isEmpty) {
      final hasAny = provider.transactions.isNotEmpty;
      return _EmptyNotice(
        icon: hasAny
            ? Icons.filter_alt_off_rounded
            : Icons.receipt_long_rounded,
        title: hasAny ? 'Tidak Ada Hasil' : 'Belum Ada Transaksi',
        message: hasAny
            ? 'Tidak ada transaksi untuk filter ini.'
            : 'Catat pemasukan atau pengeluaran grup lewat tombol '
                'Catat di atas.',
      );
    }

    final items = <Object>[];
    String? lastDate;
    for (final tx in txs) {
      if (tx.date != lastDate) {
        items.add(tx.date);
        lastDate = tx.date;
      }
      items.add(tx);
    }

    return RefreshIndicator(
      color: t.accent,
      onRefresh: provider.refreshGroup,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is String) {
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 10 : 18,
                bottom: 8,
              ),
              child: Text(
                _dateHeader(item),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionTile(
              tx: item as GroupTransaction,
              memberName: provider.memberById(item.memberId)?.name,
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, this.memberName});

  final GroupTransaction tx;
  final String? memberName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (tx.type) {
      case TxType.dues:
        color = t.accent;
        icon = Icons.checklist_rounded;
        title = memberName ?? 'Iuran';
        subtitle = tx.note?.isNotEmpty == true
            ? tx.note!
            : 'Pembayaran iuran';
      case TxType.otherIncome:
        color = t.income;
        icon = Icons.arrow_downward_rounded;
        title = tx.category?.isNotEmpty == true ? tx.category! : 'Pemasukan';
        subtitle = tx.note?.isNotEmpty == true
            ? tx.note!
            : 'Pemasukan lain';
      case TxType.expense:
        color = t.expense;
        icon = Icons.arrow_upward_rounded;
        title = tx.category?.isNotEmpty == true
            ? tx.category!
            : 'Pengeluaran';
        subtitle = tx.note?.isNotEmpty == true ? tx.note! : 'Pengeluaran';
    }

    final amountColor =
        tx.type == TxType.expense ? t.expense : t.income;
    final amountPrefix = tx.type == TxType.expense ? '−' : '+';

    return GestureDetector(
      onTap: () => TransactionFormSheet.show(context, existing: tx),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: t.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$amountPrefix${formatRupiah(tx.amount)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.softSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: t.accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
