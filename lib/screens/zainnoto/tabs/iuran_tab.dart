import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/palette_sheet.dart';
import '../../../widgets/status_badge.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';
import '../group_picker_screen.dart';
import '../widgets/group_chip.dart';
import '../widgets/iuran_matrix.dart';
import '../widgets/member_form.dart';
import '../widgets/pay_dues_sheet.dart';
import '../widgets/payment_detail_sheet.dart';

/// Tab Iuran Kas dari `docs/mockup/ZN-Iuran.dc.html` (checklist) dan
/// `ZN-Matriks.dc.html` (matriks): toggle tampilan, checklist lingkaran 28,
/// badge Lunas/Telat/Cicil dari token, dan sheet Bayar (ZN-Bayar).
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
    final hasGroup = provider.groups.isNotEmpty;

    final header = AppHeader(
      title: 'ZainNoto',
      onPaletteTap: () => showPaletteSheet(context),
      topRow: GroupChip(
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
                  : const _EmptyNotice(
                      icon: Icons.groups_rounded,
                      title: 'Belum Ada Grup',
                      message: 'Buat grup dulu di tab Beranda.',
                    ),
            ),
          ],
        ),
      );
    }

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
            child: RefreshIndicator(
              color: t.accent,
              onRefresh: provider.refreshGroup,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Iuran kas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ViewToggle(
                    matrixMode: _matrixMode,
                    onChanged: (value) => setState(() => _matrixMode = value),
                  ),
                  const SizedBox(height: 14),
                  if (_matrixMode)
                    const IuranMatrix()
                  else
                    ..._checklist(provider, t),
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

  List<Widget> _checklist(ZainNotoProvider provider, AppTokens t) {
    final period = provider.selectedPeriod;
    if (period == null) {
      return const [
        _EmptyNotice(
          icon: Icons.event_busy_rounded,
          title: 'Belum Ada Periode',
          message: 'Atur rencana iuran lewat pengaturan grup di tab Beranda '
              'untuk mulai membuat periode.',
        ),
      ];
    }
    final rows = provider.periodRows;
    if (rows.isEmpty) {
      return [
        _EmptyNotice(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Belum Ada Tagihan',
          message: 'Tambahkan anggota agar tagihan periode ini terbuat '
              'otomatis.',
          actionLabel: 'Tambah Anggota',
          onAction: () => showMemberForm(context),
        ),
      ];
    }

    var lunas = 0;
    var paidSum = 0;
    var dueSum = 0;
    for (final row in rows) {
      if (!row.waived) {
        paidSum += row.paid;
        dueSum += row.amountDue;
      }
      if (row.status == ChargeStatus.paid) lunas++;
    }
    final counted = rows.where((row) => !row.waived).length;

    return [
      _PeriodNavigator(provider: provider),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$lunas dari $counted lunas',
                  style: TextStyle(
                    fontSize: AppText.bodyLarge,
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
                  'Terkumpul ${formatRupiah(paidSum)} / '
                  '${formatRupiah(dueSum).replaceFirst('Rp ', '')}',
                  style: TextStyle(
                    fontSize: AppText.body,
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              _ChecklistRow(
                row: rows[i],
                period: period,
                first: i == 0,
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Ketuk lingkaran untuk mencatat bayar. Bayar lebih dari tagihan '
          'menjadi kredit dan dipakai otomatis di periode berikutnya.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppText.body,
            height: 1.6,
            color: t.textMuted,
          ),
        ),
      ),
    ];
  }
}

// ─── Toggle Checklist/Matriks ─────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.matrixMode, required this.onChanged});

  final bool matrixMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              segmentKey: const ValueKey('zn-view-checklist'),
              label: 'Checklist',
              active: !matrixMode,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleSegment(
              segmentKey: const ValueKey('zn-view-matriks'),
              label: 'Matriks',
              active: matrixMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.segmentKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key segmentKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      key: segmentKey,
      behavior: HitTestBehavior.opaque,
      onTap: active
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppText.body,
            fontWeight: FontWeight.w600,
            color: active ? t.onAccent : t.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Navigasi periode ─────────────────────────────────────────────────────────
class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.provider});

  final ZainNotoProvider provider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final periods = provider.periods;
    final selected = provider.selectedPeriod!;
    final index = periods.indexWhere((period) => period.id == selected.id);
    final canPrev = index > 0;
    final canNext = index >= 0 && index < periods.length - 1;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _Arrow(
            buttonKey: const ValueKey('zn-period-prev'),
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            onTap: () => provider.selectPeriod(periods[index - 1]),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Periode:',
                    style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w500,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selected.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Arrow(
            buttonKey: const ValueKey('zn-period-next'),
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            onTap: () => provider.selectPeriod(periods[index + 1]),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.buttonKey,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? t.textPrimary : t.textMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Baris checklist ──────────────────────────────────────────────────────────
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.row,
    required this.period,
    required this.first,
  });

  final PeriodMemberRow row;
  final Period period;
  final bool first;

  StatusKind? _badgeKind(bool overdue) {
    switch (row.status) {
      case ChargeStatus.paid:
        return StatusKind.lunas;
      case ChargeStatus.partial:
        return StatusKind.cicil;
      case ChargeStatus.unpaid:
        return overdue ? StatusKind.telat : null;
      case ChargeStatus.waived:
        return null;
    }
  }

  String _badgeLabel(bool overdue) {
    switch (row.status) {
      case ChargeStatus.paid:
        return 'Lunas';
      case ChargeStatus.partial:
        return 'Cicil';
      case ChargeStatus.unpaid:
        return overdue ? 'Telat' : 'Belum';
      case ChargeStatus.waived:
        return 'Bebas';
    }
  }

  String _shortDate(DateTime date) =>
      '${date.day} ${_shortMonths[date.month - 1]}';

  String _subtitle(
    ZainNotoProvider provider,
    bool overdue,
  ) {
    switch (row.status) {
      case ChargeStatus.paid:
        return 'Bayar ${formatRupiah(row.paid)}';
      case ChargeStatus.partial:
        return 'Masuk ${formatRupiah(row.paid)} dari '
            '${formatRupiah(row.amountDue)}';
      case ChargeStatus.waived:
        return 'Bebas iuran';
      case ChargeStatus.unpaid:
        if (!overdue) {
          return 'Jatuh tempo ${_shortDate(row.dueDate)}'
              ' · sisa ${formatRupiah(row.remaining)}';
        }
        final days = dateOnly(provider.now)
            .difference(dateOnly(row.dueDate))
            .inDays;
        var periods = 1;
        for (final summary in provider.overdueMembers) {
          if (summary.memberId == row.memberId) {
            periods = summary.unpaidPeriodsCount;
            break;
          }
        }
        final suffix = periods > 1 ? ' · $periods periode' : '';
        return 'Telat $days hari$suffix · sisa ${formatRupiah(row.remaining)}';
    }
  }

  Color _subtitleColor(AppTokens t, bool overdue) {
    if (row.status == ChargeStatus.partial) return t.cicilFg;
    if (row.status == ChargeStatus.unpaid && overdue) return t.telatFg;
    return t.textMuted;
  }

  Future<void> _openPayment(BuildContext context) {
    return PayDuesSheet.show(context, row: row, period: period);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = context.read<ZainNotoProvider>();
    final overdue = row.isOverdue(provider.now);
    final kind = _badgeKind(overdue);

    return GestureDetector(
      key: ValueKey('zn-iuran-row-${row.memberName}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => PaymentDetailSheet.show(context, row: row, period: period),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            _PayCircle(
              row: row,
              overdue: overdue,
              onTap: row.waived || row.status == ChargeStatus.paid
                  ? null
                  : () => _openPayment(context),
            ),
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
                      fontSize: AppText.bodyLarge,
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _subtitle(provider, overdue),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppText.body,
                        color: _subtitleColor(t, overdue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (kind != null) ...[
              const SizedBox(width: 8),
              StatusBadge(label: _badgeLabel(overdue), kind: kind),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayCircle extends StatelessWidget {
  const _PayCircle({
    required this.row,
    required this.overdue,
    required this.onTap,
  });

  final PeriodMemberRow row;
  final bool overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget? icon;
    Color background = Colors.transparent;
    Color border = t.textMuted.withValues(alpha: 0.35);
    String semantics = 'Belum lunas, ketuk untuk menandai';

    switch (row.status) {
      case ChargeStatus.paid:
        background = t.accent;
        border = t.accent;
        icon = const Icon(Icons.check_rounded, size: 14, color: Colors.white);
        semantics = 'Lunas';
      case ChargeStatus.partial:
        background = t.cicilBg;
        border = t.warning;
        icon = Icon(Icons.remove_rounded, size: 12, color: t.cicilFg);
        semantics = 'Cicil';
      case ChargeStatus.waived:
        background = t.softSurface;
        border = t.border;
        icon = Icon(Icons.block_rounded, size: 12, color: t.textMuted);
        semantics = 'Bebas iuran';
      case ChargeStatus.unpaid:
        semantics = overdue
            ? 'Telat, ketuk untuk mencatat bayar'
            : 'Belum lunas, ketuk untuk menandai';
    }

    return Semantics(
      button: onTap != null,
      label: semantics,
      child: GestureDetector(
        key: ValueKey('zn-pay-${row.memberName}'),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: icon,
        ),
      ),
    );
  }
}

// ─── Empty & error ────────────────────────────────────────────────────────────
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
              style: TextStyle(
                fontSize: AppText.bodyLarge,
                height: 1.5,
                color: t.textMuted,
              ),
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
          Icon(Icons.error_outline_rounded, color: t.expense, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: AppText.body, color: t.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
