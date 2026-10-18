import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/decorative_header_circles.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/format.dart';
import '../widgets/dues_style.dart';
import '../widgets/iuran_matrix.dart';
import '../widgets/member_avatar.dart';
import '../widgets/member_form.dart';
import '../widgets/payment_detail_sheet.dart';

/// Iuran tab: per-period checklist with 1-tap payments and a members ×
/// periods matrix, both opening the payment detail sheet.
class IuranTab extends StatefulWidget {
  const IuranTab({super.key});

  @override
  State<IuranTab> createState() => _IuranTabState();
}

class _IuranTabState extends State<IuranTab> {
  bool _matrixMode = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: group != null
          ? FloatingActionButton.extended(
              heroTag: 'zainnoto-iuran-fab',
              onPressed: () => showMemberForm(context),
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text(
                'Tambah Anggota',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppText.bodyLarge,
                ),
              ),
              elevation: 4,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            provider: provider,
            matrixMode: _matrixMode,
            onModeChanged: (value) => setState(() => _matrixMode = value),
          ),
          if (provider.isRefreshing)
            LinearProgressIndicator(
              minHeight: 2,
              color: t.accent,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: group == null
                ? const _EmptyNotice(
                    icon: Icons.groups_rounded,
                    title: 'Belum Ada Grup',
                    message: 'Buat grup dulu di tab Beranda.',
                  )
                : _matrixMode
                    ? const IuranMatrix()
                    : const _Checklist(),
          ),
        ],
      ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  const _Banner({
    required this.provider,
    required this.matrixMode,
    required this.onModeChanged,
  });

  final ZainNotoProvider provider;
  final bool matrixMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = provider.periodRows;
    final counted =
        rows.where((row) => row.status != ChargeStatus.waived).length;
    final paid = rows.where((row) => row.status == ChargeStatus.paid).length;

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
                          'Iuran Kas',
                          style: TextStyle(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w800,
                            color: t.headerFg,
                          ),
                        ),
                      ),
                      if (counted > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: t.headerSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: t.headerBorder),
                          ),
                          child: Text(
                            '$paid/$counted lunas',
                            style: TextStyle(
                              fontSize: AppText.label,
                              fontWeight: FontWeight.w600,
                              color: t.headerFg,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PeriodNavigator(provider: provider),
                  const SizedBox(height: 14),
                  _ViewToggle(matrixMode: matrixMode, onChanged: onModeChanged),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final periods = provider.periods;
    final selected = provider.selectedPeriod;

    if (selected == null) {
      return Text(
        'Belum ada periode iuran',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppText.subtitle,
          fontWeight: FontWeight.w600,
          color: t.headerMuted,
        ),
      );
    }

    final index = periods.indexWhere((period) => period.id == selected.id);
    final canPrev = index > 0;
    final canNext = index >= 0 && index < periods.length - 1;

    return Row(
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          enabled: canPrev,
          onTap: () => provider.selectPeriod(periods[index - 1]),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                selected.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.subtitle,
                  fontWeight: FontWeight.w700,
                  color: t.headerFg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Jatuh tempo ${formatTanggalSingkat(selected.dueDate)}',
                style: TextStyle(fontSize: AppText.label, color: t.headerMuted),
              ),
            ],
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          enabled: canNext,
          onTap: () => provider.selectPeriod(periods[index + 1]),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? t.headerSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: enabled ? t.headerBorder : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? t.headerFg
              : t.headerMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.matrixMode, required this.onChanged});

  static const double _height = 34;

  final bool matrixMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.headerSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.headerBorder),
      ),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: matrixMode
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: thumbWidth,
                    height: _height,
                    decoration: BoxDecoration(
                      color: t.headerFg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleSegment(
                        icon: Icons.checklist_rounded,
                        label: 'Checklist',
                        active: !matrixMode,
                        onTap: () => onChanged(false),
                      ),
                    ),
                    Expanded(
                      child: _ToggleSegment(
                        icon: Icons.grid_view_rounded,
                        label: 'Matriks',
                        active: matrixMode,
                        onTap: () => onChanged(true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.headerBg : t.headerMuted;

    return GestureDetector(
      onTap: active
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, _) =>
                  Icon(icon, size: 15, color: value),
            ),
            const SizedBox(width: 6),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, _) => Text(
                label,
                style: TextStyle(
                  fontSize: AppText.body,
                  fontWeight: FontWeight.w700,
                  color: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Checklist ────────────────────────────────────────────────────────────────
class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final period = provider.selectedPeriod;
    final rows = provider.periodRows;

    if (period == null) {
      return const _EmptyNotice(
        icon: Icons.event_busy_rounded,
        title: 'Belum Ada Periode',
        message: 'Atur rencana iuran lewat tombol pengaturan grup di tab '
            'Beranda untuk mulai membuat periode.',
      );
    }
    if (rows.isEmpty) {
      return _EmptyNotice(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Belum Ada Tagihan',
        message: 'Tambahkan anggota agar tagihan periode ini terbuat '
            'otomatis.',
        actionLabel: 'Tambah Anggota',
        onAction: () => showMemberForm(context),
      );
    }

    return RefreshIndicator(
      color: t.accent,
      onRefresh: provider.refreshGroup,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ChecklistItem(
          row: rows[index],
          period: period,
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.row, required this.period});

  final PeriodMemberRow row;
  final Period period;

  Future<void> _markPaid(BuildContext context) async {
    final provider = context.read<ZainNotoProvider>();
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.lightImpact();
    final txId = await provider.markPaid(
      memberId: row.memberId,
      amount: row.remaining,
    );
    if (txId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mencatat pembayaran')),
      );
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('Pembayaran ${row.memberName} berhasil dicatat'),
        action: SnackBarAction(
          label: 'Batal',
          textColor: Colors.amber,
          onPressed: () => provider.deleteTransaction(txId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = row.status;
    final overdue = row.isOverdue(DateTime.now());
    final color = duesStatusColor(t, status, overdue: overdue);

    return GestureDetector(
      onTap: () => PaymentDetailSheet.show(context, row: row, period: period),
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
            MemberAvatar(name: row.memberName, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(
                        label: duesStatusLabel(status),
                        color: color,
                      ),
                      if (status == ChargeStatus.partial) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Sisa ${formatRupiah(row.remaining)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppText.label,
                              color: t.textMuted,
                            ),
                          ),
                        ),
                      ] else if (status == ChargeStatus.unpaid) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            overdue
                                ? 'Lewat '
                                    '${formatTanggalSingkat(period.dueDate)}'
                                : 'Jatuh tempo '
                                    '${formatTanggalSingkat(period.dueDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppText.label,
                              color: overdue ? t.expense : t.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(row.amountDue),
                  style: TextStyle(
                    fontSize: AppText.bodyLarge,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _action(context, t, status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, AppTokens t, ChargeStatus status) {
    switch (status) {
      case ChargeStatus.paid:
        return Icon(Icons.check_circle_rounded, size: 22, color: t.income);
      case ChargeStatus.waived:
        return Icon(Icons.block_rounded, size: 20, color: t.textMuted);
      case ChargeStatus.unpaid:
      case ChargeStatus.partial:
        return GestureDetector(
          onTap: () => _markPaid(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 14, color: t.accent),
                const SizedBox(width: 4),
                Text(
                  'Lunas',
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppText.micro,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                fontSize: AppText.title,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.bodyLarge, height: 1.5, color: t.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
