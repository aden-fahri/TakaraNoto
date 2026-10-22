import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import 'member_form.dart';
import 'payment_detail_sheet.dart';

/// Matriks rekap iuran dari `docs/mockup/ZN-Matriks.dc.html`: 4 periode
/// terakhir, kolom anggota 72 + 4 kolom periode sama lebar, sel 30x30 radius
/// 10 berisi OK / ½ / ! / -, legenda, dan catatan.
class IuranMatrix extends StatefulWidget {
  const IuranMatrix({super.key});

  @override
  State<IuranMatrix> createState() => _IuranMatrixState();
}

class _IuranMatrixState extends State<IuranMatrix> {
  static const int _maxPeriods = 4;
  static const double _memberColumnWidth = 72;
  static const double _cellSize = 30;

  static const List<String> _shortMonths = [
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

  bool _loadScheduled = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;

    if (!provider.matrixNeedsReload) {
      _loadScheduled = false;
    } else if (!_loadScheduled && !provider.isLoadingMatrix) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadMatrix(maxPeriods: _maxPeriods);
      });
    }

    if (provider.isLoadingMatrix && provider.matrixByPeriod.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: t.accent)),
      );
    }

    final allPeriods = provider.periods;
    final periods = allPeriods.length <= _maxPeriods
        ? allPeriods
        : allPeriods.sublist(allPeriods.length - _maxPeriods);
    final members = provider.members;

    if (periods.isEmpty) {
      return const _MatrixNotice(
        icon: Icons.event_busy_rounded,
        title: 'Belum Ada Periode Iuran',
        message: 'Atur rencana iuran di menu Kelola untuk membuat periode '
            'dan jadwal iuran.',
      );
    }
    if (members.isEmpty) {
      return _MatrixNotice(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Belum Ada Anggota',
        message: 'Tambahkan anggota agar tagihan otomatis terbuat.',
        actionLabel: 'Tambah Anggota',
        onAction: () => showMemberForm(context),
      );
    }

    final rowsByPeriod = <String, Map<String, PeriodMemberRow>>{};
    for (final period in periods) {
      final map = <String, PeriodMemberRow>{};
      for (final row in provider.matrixByPeriod[period.id] ??
          const <PeriodMemberRow>[]) {
        map[row.memberId] = row;
      }
      rowsByPeriod[period.id] = map;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _headerRow(periods, t),
              for (final member in members)
                _memberRow(
                  member,
                  periods,
                  rowsByPeriod,
                  provider.now,
                  t,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Legend(tokens: t),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Anggota baru hanya ditagih sejak periode bergabungnya. '
            'Ketuk sel untuk melihat atau mencatat pembayaran.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.body,
              height: 1.6,
              color: t.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(List<Period> periods, AppTokens t) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: _memberColumnWidth,
            child: Text(
              'Anggota',
              maxLines: 1,
              style: TextStyle(
                fontSize: AppText.label,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
          ),
          for (final period in periods)
            Expanded(
              child: Center(
                child: Text(
                  _headerLabel(period),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberRow(
    Member member,
    List<Period> periods,
    Map<String, Map<String, PeriodMemberRow>> rowsByPeriod,
    DateTime now,
    AppTokens t,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _memberColumnWidth,
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppText.bodyLarge,
                fontWeight: FontWeight.w500,
                color: t.textPrimary,
              ),
            ),
          ),
          for (final period in periods)
            Expanded(
              child: Center(
                child: _cell(
                  memberId: member.id,
                  row: rowsByPeriod[period.id]?[member.id],
                  period: period,
                  now: now,
                  t: t,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell({
    required String memberId,
    required PeriodMemberRow? row,
    required Period period,
    required DateTime now,
    required AppTokens t,
  }) {
    final (mark, bg, fg) = _cellStyle(row, now, t);
    return GestureDetector(
      onTap: row == null
          ? null
          : () => PaymentDetailSheet.show(context, row: row, period: period),
      child: Container(
        key: ValueKey('zn-cell-$memberId-${period.id}'),
        width: _cellSize,
        height: _cellSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          mark,
          style: TextStyle(
            fontSize: AppText.label,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _cellStyle(
    PeriodMemberRow? row,
    DateTime now,
    AppTokens t,
  ) {
    if (row == null) return ('-', t.softSurface, t.textMuted);
    switch (row.status) {
      case ChargeStatus.paid:
        return ('OK', t.lunasBg, t.lunasFg);
      case ChargeStatus.partial:
        return ('½', t.cicilBg, t.cicilFg);
      case ChargeStatus.waived:
        return ('-', t.softSurface, t.textMuted);
      case ChargeStatus.unpaid:
        if (row.isOverdue(now)) return ('!', t.telatBg, t.telatFg);
        return ('·', t.softSurface, t.textMuted);
    }
  }

  String _headerLabel(Period period) {
    final start = DateTime.tryParse(period.startDate);
    if (start == null) return period.label;
    if (period.label.startsWith('Minggu')) {
      return '${start.day} ${_shortMonths[start.month - 1]}';
    }
    return _shortMonths[start.month - 1];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _item('Lunas', tokens.lunasBg),
        _item('Cicil', tokens.cicilBg),
        _item('Telat', tokens.telatBg),
        _item('Belum bergabung', tokens.softSurface),
      ],
    );
  }

  Widget _item(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: AppText.body,
            color: tokens.textMuted,
          ),
        ),
      ],
    );
  }
}

class _MatrixNotice extends StatelessWidget {
  const _MatrixNotice({
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

    return Padding(
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
    );
  }
}
