import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/decorative_header_circles.dart';
import '../../../widgets/mode_switch_button.dart';
import '../../../widgets/notched_card.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';
import '../../../zainnoto/utils/whatsapp.dart';
import '../widgets/group_avatar.dart';
import '../widgets/group_management_sheet.dart';
import '../widgets/group_sheets.dart';
import '../widgets/transaction_form_sheet.dart';

/// Beranda tab: Redesigned header, modern wallet card (serasi dengan TakaraNoto),
/// live status iuran & tunggakan, quick actions, and direct FAB catat pengeluaran/belanja.
class BerandaTab extends StatelessWidget {
  const BerandaTab({super.key, required this.onGoToTab});

  final ValueChanged<int> onGoToTab;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: group != null
          ? FloatingActionButton.extended(
              heroTag: 'zainnoto-beranda-fab',
              onPressed: () => TransactionFormSheet.show(context),
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text(
                'Catat Belanja / Kas Keluar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              elevation: 4,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            group: group,
            onSwitch: () => showGroupSwitcher(context),
            onManageGroup: () => GroupManagementSheet.show(context),
          ),
          if (provider.isRefreshing)
            LinearProgressIndicator(
              minHeight: 2,
              color: t.accent,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: provider.isLoading && provider.groups.isEmpty
                ? Center(child: CircularProgressIndicator(color: t.accent))
                : provider.groups.isEmpty
                    ? _EmptyGroups(
                        error: provider.error,
                        onCreate: () => showCreateGroupDialog(context),
                        onRetry: provider.loadGroups,
                      )
                    : RefreshIndicator(
                        color: t.accent,
                        onRefresh: provider.refreshGroup,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                          children: [
                            // Modern Wallet Card untuk Kas Kelompok
                            _ModernGroupWalletCard(provider: provider),
                            const SizedBox(height: 14),

                            // Bento Stats: Keaktifan & Tunggakan
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _ActivityCard(
                                      provider: provider,
                                      onTap: () => onGoToTab(1),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _OverdueCard(
                                      overdueTotal:
                                          provider.summary?.overdueTotal ?? 0,
                                      overdueCount:
                                          provider.summary?.overdueMemberCount ?? 0,
                                      onTap: () => onGoToTab(1),
                                      onShowList: () =>
                                          _showOverdueSheet(context, provider),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Quick Action Shortcuts
                            _QuickActions(
                              onGoToTab: onGoToTab,
                              onOpenSettings: () => GroupManagementSheet.show(context),
                            ),

                            if (provider.error != null) ...[
                              const SizedBox(height: 14),
                              _ErrorCard(
                                message: provider.error!,
                                onRetry: provider.refreshGroup,
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Header Banner ────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  const _Banner({
    required this.group,
    required this.onSwitch,
    required this.onManageGroup,
  });

  final Group? group;
  final VoidCallback onSwitch;
  final VoidCallback onManageGroup;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = group?.name ?? 'Belum ada grup';

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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  Row(
                children: [
                  if (group != null)
                    GroupAvatar(
                      name: group!.name,
                      colorHex: group!.colorHex,
                      iconIndex: group!.iconIndex,
                      size: 46,
                    )
                  else
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.headerSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.headerBorder, width: 1.5),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        color: t.headerFg,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Kelompok · Kas Bersama',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: t.headerMuted,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.headerFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ModeSwitchButton(),
                  const SizedBox(width: 8),
                  if (group != null) ...[
                    Tooltip(
                      message: 'Kelola grup & anggota',
                      child: GestureDetector(
                        onTap: onManageGroup,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: t.headerSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.headerBorder, width: 1),
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            color: t.headerFg,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Tooltip(
                    message: 'Ganti grup',
                    child: GestureDetector(
                      onTap: onSwitch,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.headerSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.headerBorder, width: 1),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: t.headerFg,
                          size: 22,
                        ),
                      ),
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

// ─── Modern Group Wallet Card ─────────────────────────────────────────────────
class _ModernGroupWalletCard extends StatelessWidget {
  const _ModernGroupWalletCard({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final balance = provider.summary?.balance ?? 0;
    final totalIn = provider.totalIncome;
    final totalOut = provider.totalExpense;
    final period = provider.currentPeriod;

    return NotchedCard(
      color: t.card,
      borderColor: t.border,
      borderWidth: 1.2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shadowBlur: 14,
      shadowOffset: const Offset(0, 4),
      child: Stack(
        children: [
          // Main Card Contents
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: t.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DOMPET KAS KELOMPOK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: t.textPrimary,
                      ),
                    ),
                    if (period != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.softSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.border),
                        ),
                        child: Text(
                          period.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Saldo Kas Utama (Besar)
                Text(
                  'Saldo Kas Bersama',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(balance),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: balance >= 0 ? t.textPrimary : t.expense,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Kas Masuk & Kas Keluar Pills
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.income.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.income.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 13,
                            color: t.income,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Masuk: ${formatRupiah(totalIn)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.expense.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.expense.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 13,
                            color: t.expense,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Keluar: ${formatRupiah(totalOut)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bento Cards ──────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.provider, required this.onTap});

  final ZainNotoProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final summary = provider.summary;
    final paid = summary?.currentPeriodPaidCount ?? 0;
    final total = summary?.currentPeriodTotalCount ?? 0;
    final pct = summary?.activityPct ?? 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconChip(icon: Icons.checklist_rounded, color: t.accent),
                Icon(Icons.chevron_right_rounded, size: 18, color: t.textMuted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Iuran Periode Ini',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0 ? '—' : '$paid / $total lunas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              provider.currentPeriod?.label ?? 'Belum ada periode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: t.textMuted),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : pct / 100,
                minHeight: 5,
                color: t.income,
                backgroundColor: t.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  const _OverdueCard({
    required this.overdueTotal,
    required this.overdueCount,
    required this.onTap,
    required this.onShowList,
  });

  final int overdueTotal;
  final int overdueCount;
  final VoidCallback onTap;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasOverdue = overdueTotal > 0;

    return GestureDetector(
      onTap: hasOverdue ? onShowList : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconChip(
                  icon: Icons.error_outline_rounded,
                  color: hasOverdue ? t.expense : t.income,
                ),
                if (hasOverdue && overdueCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.expense.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$overdueCount orang',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: t.expense,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tunggakan',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(overdueTotal),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: hasOverdue ? t.expense : t.income,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasOverdue ? 'Ketuk untuk rincian' : 'Semua iuran lancar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: hasOverdue ? t.expense : t.textMuted,
                fontWeight: hasOverdue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onGoToTab,
    required this.onOpenSettings,
  });

  final ValueChanged<int> onGoToTab;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.checklist_rounded,
            label: 'Catat Iuran',
            onTap: () => onGoToTab(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_rounded,
            label: 'Transaksi',
            onTap: () => onGoToTab(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.analytics_rounded,
            label: 'Statistik',
            onTap: () => onGoToTab(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.settings_rounded,
            label: 'Kelola',
            onTap: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: t.accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
          ],
        ),
      ),
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
              style: TextStyle(fontSize: 12.5, color: t.expense),
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat grup kas pertamamu untuk mulai mencatat iuran anggota dan belanja bersama secara rapi dan transparan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: t.textMuted),
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
                              fontSize: 12.5,
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
                      style: TextStyle(fontSize: 11.5, color: t.expense),
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

// ─── Overdue Bottom Sheet ─────────────────────────────────────────────────────
void _showOverdueSheet(BuildContext context, ZainNotoProvider provider) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _OverdueListSheet(provider: provider),
  );
}

class _OverdueListSheet extends StatelessWidget {
  const _OverdueListSheet({required this.provider});

  final ZainNotoProvider provider;

  Member? _memberById(String id) {
    for (final member in provider.allMembers) {
      if (member.id == id) return member;
    }
    return null;
  }

  Future<void> _chargeViaWhatsApp(
    BuildContext context,
    MemberOverdueSummary item,
    Member member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final groupName = provider.selectedGroup?.name ?? 'kas';
    final message =
        'Halo ${item.memberName}, iuran $groupName kamu masih kurang '
        '${formatRupiah(item.totalOverdueAmount)} untuk '
        '${item.unpaidPeriodsCount} periode '
        '(sejak ${formatTanggalSingkat(dateToStr(item.oldestDueDate))}). '
        'Mohon dilunasi ya. Terima kasih.';
    final ok = await openWhatsApp(member.phoneNumber, message: message);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp tidak bisa dibuka')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overdueList = provider.overdueMembers;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.expense.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: t.expense, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Penunggak Kas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        '${overdueList.length} anggota belum melunasi kas',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (overdueList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tidak ada tunggakan!',
                    style: TextStyle(color: t.income, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: overdueList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = overdueList[index];
                    final member = _memberById(item.memberId);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.softSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: t.expense.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                item.memberName.isNotEmpty
                                    ? item.memberName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: t.expense,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.memberName,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nunggak ${item.unpaidPeriodsCount} periode (sejak ${formatTanggalSingkat(dateToStr(item.oldestDueDate))})',
                                  style: TextStyle(fontSize: 11, color: t.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(item.totalOverdueAmount),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: t.expense,
                            ),
                          ),
                          if (member != null && member.phoneNumber != null) ...[
                            const SizedBox(width: 2),
                            IconButton(
                              onPressed: () =>
                                  _chargeViaWhatsApp(context, item, member),
                              tooltip: 'Tagih via WhatsApp',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.chat_rounded,
                                size: 18,
                                color: t.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
