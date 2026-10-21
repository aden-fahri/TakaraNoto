import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/list_row.dart';
import '../../../widgets/notched_card.dart';
import '../../../widgets/palette_sheet.dart';
import '../../../widgets/status_badge.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/format.dart';
import '../group_picker_screen.dart';
import '../widgets/group_management_sheet.dart';
import '../widgets/group_sheets.dart';
import '../widgets/transaction_form_sheet.dart';

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

/// `2026-10-01` → `Okt 2026` (chip bulan di takik kartu saldo).
String _monthChipLabel(String iso) {
  try {
    final p = iso.split('-');
    return '${_shortMonths[int.parse(p[1]) - 1]} ${p[0]}';
  } catch (_) {
    return iso;
  }
}

/// `2026-10-10` → `10 Okt` (baris jatuh tempo kartu iuran).
String _dueLabel(String iso) {
  try {
    final p = iso.split('-');
    return '${int.parse(p[2])} ${_shortMonths[int.parse(p[1]) - 1]}';
  } catch (_) {
    return iso;
  }
}

/// `2026-10-10` → `Hari ini` / `Kemarin` / `10 Oktober 2026`.
String _dateLabel(String iso) {
  final date = DateTime.tryParse(iso);
  if (date != null) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Hari ini';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
  }
  return formatTanggal(iso);
}

/// Beranda ZainNoto dari `docs/mockup/ZN-Beranda.dc.html`: header 172 + chip
/// grup, kartu saldo bertakik, 4 tile tindakan, kartu iuran, tunggakan,
/// dan aktivitas terbaru.
class BerandaTab extends StatelessWidget {
  const BerandaTab({super.key, required this.onGoToTab});

  final ValueChanged<int> onGoToTab;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;
    final hasGroup = provider.groups.isNotEmpty;

    final header = AppHeader(
      height: 172,
      title: 'ZainNoto',
      onPaletteTap: () => showPaletteSheet(context),
      topRow: _GroupChip(
        name: group?.name ?? 'Belum ada grup',
        onTap: () => GroupPickerScreen.show(context),
      ),
    );

    if (!hasGroup) {
      return Scaffold(
        backgroundColor: t.pageBg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (provider.isRefreshing)
              LinearProgressIndicator(
                minHeight: 2,
                color: t.accent,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: provider.isLoading
                  ? Center(child: CircularProgressIndicator(color: t.accent))
                  : _EmptyGroups(
                      error: provider.error,
                      onCreate: () => showCreateGroupDialog(context),
                      onRetry: provider.loadGroups,
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.pageBg,
      body: Stack(
        children: [
          // ── Header (tinggi 172, kartu saldo menimpa) ────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: header),

          // ── Konten: mulai di top 96, terpotong di batas itu ─────────────────
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: RefreshIndicator(
                color: t.accent,
                onRefresh: provider.refreshGroup,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    if (provider.isRefreshing)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: t.accent,
                        backgroundColor: Colors.transparent,
                      ),
                    _BalanceCard(provider: provider),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _ActionTile(
                          tileKey: const ValueKey('zn-tile-anggota'),
                          icon: Icons.groups_rounded,
                          label: 'Anggota',
                          boxColor: t.softSurface,
                          iconColor: t.accent,
                          onTap: () => GroupManagementSheet.show(context),
                        ),
                        const SizedBox(width: 10),
                        _ActionTile(
                          tileKey: const ValueKey('zn-tile-setor'),
                          icon: Icons.north_rounded,
                          label: 'Setor kas',
                          boxColor: t.lunasBg,
                          iconColor: t.income,
                          onTap: () => onGoToTab(1),
                        ),
                        const SizedBox(width: 10),
                        _ActionTile(
                          tileKey: const ValueKey('zn-tile-keluar'),
                          icon: Icons.south_rounded,
                          label: 'Pengeluaran',
                          boxColor: t.telatBg,
                          iconColor: t.expense,
                          onTap: () => TransactionFormSheet.show(context),
                        ),
                        const SizedBox(width: 10),
                        _ActionTile(
                          tileKey: const ValueKey('zn-tile-pengaturan'),
                          icon: Icons.tune_rounded,
                          label: 'Pengaturan',
                          boxColor: t.cicilBg,
                          iconColor: t.cicilFg,
                          onTap: () => GroupManagementSheet.show(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (provider.currentPeriod != null) ...[
                      _IuranCard(provider: provider),
                      const SizedBox(height: 16),
                    ],
                    _TunggakanCard(provider: provider),
                    const SizedBox(height: 16),
                    _AktivitasCard(
                      provider: provider,
                      onSeeAll: () => onGoToTab(2),
                    ),
                    if (provider.error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorCard(
                        message: provider.error!,
                        onRetry: provider.refreshGroup,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip grup di header ───────────────────────────────────────────────────────
class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const ValueKey('zn-group-chip'),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('zn-group-chip-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: t.persik,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
    );
  }
}

// ─── Kartu saldo bertakik ─────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final period = provider.currentPeriod;
    final balance = provider.summary?.balance ?? 0;
    final members = provider.members.length;
    final plan = provider.duesPlans.isNotEmpty
        ? provider.duesPlans.first
        : null;
    final freqLabel = plan?.frequency == DuesFrequency.weekly
        ? 'minggu'
        : 'bulan';

    return NotchedCard(
      color: t.persik,
      borderColor: null,
      borderWidth: 0,
      child: SizedBox(
        height: 214,
        child: Stack(
          children: [
            // Chip bulan di dalam takik (kanan 10, atas 6, tinggi 32)
            if (period != null)
              Positioned(
                right: 10,
                top: 6,
                child: Container(
                  key: const ValueKey('zn-month-chip'),
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
                        _monthChipLabel(period.startDate),
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

            // Label + saldo (kiri 20, atas 18)
            Positioned(
              left: 20,
              right: 20,
              top: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo kas bersama',
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
                      formatRupiah(balance),
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

            // Dua kotak masuk/keluar (kiri-kanan 20, atas 92)
            Positioned(
              left: 20,
              right: 20,
              top: 92,
              child: Row(
                children: [
                  Expanded(
                    child: _FlowBox(
                      label: 'Masuk bulan ini',
                      value: formatRupiah(provider.incomeThisPeriod),
                      valueColor: t.incomeOnPersik,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FlowBox(
                      label: 'Keluar bulan ini',
                      value: formatRupiah(provider.expenseThisPeriod),
                      valueColor: t.expenseOnPersik,
                    ),
                  ),
                ],
              ),
            ),

            // Ringkasan anggota & iuran (kiri-kanan 20, atas 164, tinggi 36)
            Positioned(
              left: 20,
              right: 20,
              top: 164,
              height: 36,
              child: Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: t.onPersik.withValues(alpha: 0.18)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '$members anggota aktif',
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
                          plan == null
                              ? 'Belum ada rencana iuran'
                              : 'Iuran ${formatRupiah(plan.amount)} / $freqLabel',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppText.bodyLarge,
                            fontWeight: FontWeight.w600,
                            color: t.onPersik,
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

/// Kotak masuk/keluar di kartu saldo: label 11 + nilai 14 (mockup: 8% gelap).
class _FlowBox extends StatelessWidget {
  const _FlowBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.onPersik.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
              style: TextStyle(
                fontSize: AppText.label,
                fontWeight: FontWeight.w500,
                color: t.onPersik,
              ),
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
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile tindakan (4 kotak persegi) ──────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.boxColor,
    required this.iconColor,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final Color boxColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: tileKey,
          height: 92,
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.label,
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

// ─── Kartu iuran periode berjalan ─────────────────────────────────────────────
class _IuranCard extends StatelessWidget {
  const _IuranCard({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final period = provider.currentPeriod!;
    var lunas = 0;
    var cicil = 0;
    var telat = 0;
    var belumBayar = 0;
    var paidSum = 0;
    var dueSum = 0;
    for (final row in provider.currentPeriodRows) {
      if (row.waived) continue;
      paidSum += row.paid;
      dueSum += row.amountDue;
      if (row.status == ChargeStatus.paid) {
        lunas++;
      } else if (row.status == ChargeStatus.partial) {
        cicil++;
      } else if (row.isOverdue(DateTime.now())) {
        telat++;
      } else {
        belumBayar++;
      }
    }
    final parts = <String>[
      if (lunas > 0) '$lunas lunas',
      if (cicil > 0) '$cicil cicil',
      if (telat > 0) '$telat telat',
      if (belumBayar > 0) '$belumBayar belum bayar',
    ];
    final statuses = parts.isEmpty ? 'Belum ada pembayaran' : parts.join(' · ');
    final ratio = dueSum == 0
        ? 0.0
        : (paidSum / dueSum).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Iuran ${period.label}',
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'Jatuh tempo ${_dueLabel(period.dueDate)}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.body,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    statuses,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.bodyLarge,
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
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
                    '${formatRupiah(paidSum)} / '
                    '${formatRupiah(dueSum).replaceFirst('Rp ', '')}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.body,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('zn-iuran-bar'),
            height: 10,
            decoration: BoxDecoration(
              color: t.softSurface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: FractionallySizedBox(
                alignment: Alignment.topLeft,
                widthFactor: ratio,
                heightFactor: 1,
                child: Container(color: t.income),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kartu tunggakan ──────────────────────────────────────────────────────────
class _TunggakanCard extends StatelessWidget {
  const _TunggakanCard({required this.provider});

  final ZainNotoProvider provider;

  String _subtitleFor(String memberId) {
    for (final row in provider.currentPeriodRows) {
      if (row.memberId == memberId && row.status == ChargeStatus.partial) {
        final due = formatRupiah(row.amountDue).replaceFirst('Rp ', '');
        return 'Cicil ${formatRupiah(row.paid)} dari $due';
      }
    }
    for (final member in provider.overdueMembers) {
      if (member.memberId == memberId) {
        return '${member.unpaidPeriodsCount} periode belum lunas';
      }
    }
    return 'Belum lunas';
  }

  StatusKind _kindFor(String memberId) {
    for (final row in provider.currentPeriodRows) {
      if (row.memberId == memberId && row.status == ChargeStatus.partial) {
        return StatusKind.cicil;
      }
    }
    return StatusKind.telat;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overdue = provider.overdueMembers;
    final total = provider.summary?.overdueTotal ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Tunggakan',
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    formatRupiah(total),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.bodyLarge,
                      fontWeight: FontWeight.w700,
                      color: total > 0 ? t.expense : t.income,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (overdue.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                'Semua iuran lancar',
                style: TextStyle(fontSize: AppText.body, color: t.income),
              ),
            ),
          for (var i = 0; i < overdue.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.border),
            ListRow(
              leading: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.softSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  overdue[i].memberName.isNotEmpty
                      ? overdue[i].memberName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: AppText.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ),
              title: overdue[i].memberName,
              subtitle: _subtitleFor(overdue[i].memberId),
              trailing: StatusBadge(
                label: formatRupiah(overdue[i].totalOverdueAmount),
                kind: _kindFor(overdue[i].memberId),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Kartu aktivitas terbaru ──────────────────────────────────────────────────
class _AktivitasCard extends StatelessWidget {
  const _AktivitasCard({required this.provider, required this.onSeeAll});

  final ZainNotoProvider provider;
  final VoidCallback onSeeAll;

  String _titleOf(GroupTransaction tx) {
    if (tx.type == TxType.dues) {
      final member = provider.memberById(tx.memberId);
      if (member != null) return member.name;
    }
    final note = tx.note;
    if (note != null && note.isNotEmpty) return note;
    final category = tx.category;
    if (category != null && category.isNotEmpty) return category;
    return 'Iuran kas';
  }

  String _kindOf(GroupTransaction tx) {
    if (tx.type == TxType.dues) return 'Iuran kas';
    if (tx.type == TxType.otherIncome) return 'Pemasukan lain';
    final category = tx.category;
    if (category != null && category.isNotEmpty) return category;
    return 'Pengeluaran';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final txs = provider.transactions.take(5).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Aktivitas kas terbaru',
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
                behavior: HitTestBehavior.opaque,
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
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                'Belum ada transaksi',
                style: TextStyle(fontSize: AppText.body, color: t.textMuted),
              ),
            ),
          for (var i = 0; i < txs.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.border),
            _activityRow(context, txs[i]),
          ],
        ],
      ),
    );
  }

  Widget _activityRow(BuildContext context, GroupTransaction tx) {
    final t = context.tokens;
    final isIncome = tx.type != TxType.expense;
    final color = isIncome ? t.income : t.expense;
    final sign = isIncome ? '+' : '-';
    return ListRow(
      icon: isIncome ? Icons.north_rounded : Icons.south_rounded,
      iconColor: color,
      title: _titleOf(tx),
      subtitle: '${_kindOf(tx)} · ${_dateLabel(tx.date)}',
      amount: '$sign ${formatRupiah(tx.amount)}',
      amountColor: color,
    );
  }
}

// ─── Error & Empty States ─────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.expense.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: t.expense, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: AppText.body, color: t.expense),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Coba lagi',
              style: TextStyle(color: t.expense, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({
    this.error,
    required this.onCreate,
    required this.onRetry,
  });

  final String? error;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: SingleChildScrollView(
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
              child: Icon(Icons.groups_rounded, size: 32, color: t.accent),
            ),
            const SizedBox(height: 18),
            Text(
              'Belum Ada Grup Kas',
              style: TextStyle(
                fontSize: AppText.title,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat grup kas pertamamu untuk mulai mencatat iuran anggota dan belanja bersama secara rapi dan transparan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.bodyLarge,
                height: 1.5,
                color: t.textMuted,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.expense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.expense.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: t.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gagal memuat data',
                            style: TextStyle(
                              fontSize: AppText.body,
                              fontWeight: FontWeight.w700,
                              color: t.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$error',
                      style: TextStyle(
                        fontSize: AppText.label,
                        color: t.expense,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onRetry,
                        child: Text(
                          'Coba lagi',
                          style: TextStyle(
                            color: t.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Grup Kas Sekarang'),
            ),
          ],
        ),
      ),
    );
  }
}
