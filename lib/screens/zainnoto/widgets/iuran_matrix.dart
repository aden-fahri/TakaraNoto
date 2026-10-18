import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import 'member_form.dart';
import '../../../zainnoto/utils/format.dart';
import 'dues_style.dart';
import 'payment_detail_sheet.dart';

/// Tampilan Matriks Rekap Iuran: Baris Anggota x Kolom Periode
/// Desain modern, intuitif, berlabel Bahasa Indonesia, dan responsif.
class IuranMatrix extends StatefulWidget {
  const IuranMatrix({super.key});

  @override
  State<IuranMatrix> createState() => _IuranMatrixState();
}

class _IuranMatrixState extends State<IuranMatrix> {
  static const int _maxPeriods = 12;
  static const double _memberColumnWidth = 135;
  static const double _periodColumnWidth = 64;
  static const double _cellSize = 42;

  bool _loadScheduled = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final now = DateTime.now();

    if (!provider.matrixNeedsReload) {
      _loadScheduled = false;
    } else if (!_loadScheduled && !provider.isLoadingMatrix) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadMatrix(maxPeriods: _maxPeriods);
      });
    }

    if (provider.isLoadingMatrix && provider.matrixByPeriod.isEmpty) {
      return Center(child: CircularProgressIndicator(color: t.accent));
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
        message: 'Atur rencana iuran di menu Kelola untuk membuat periode dan jadwal iuran.',
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
      for (final row in provider.matrixByPeriod[period.id] ?? const <PeriodMemberRow>[]) {
        map[row.memberId] = row;
      }
      rowsByPeriod[period.id] = map;
    }

    return RefreshIndicator(
      color: t.accent,
      onRefresh: () => provider.loadMatrix(maxPeriods: _maxPeriods),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Matrix Table Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(periods, t),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  for (final member in members) ...[
                    _memberRow(member, periods, rowsByPeriod, now, t),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keterangan Status:',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _legend(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(List<Period> periods, AppTokens t) {
    return Row(
      children: [
        SizedBox(
          width: _memberColumnWidth,
          child: Text(
            'Nama Anggota',
            style: TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
        ),
        for (final period in periods)
          SizedBox(
            width: _periodColumnWidth,
            child: Center(
              child: _PeriodHeader(label: periodShortLabel(period)),
            ),
          ),
      ],
    );
  }

  Widget _memberRow(
    Member member,
    List<Period> periods,
    Map<String, Map<String, PeriodMemberRow>> rowsByPeriod,
    DateTime now,
    AppTokens t,
  ) {
    return Row(
      children: [
        SizedBox(
          width: _memberColumnWidth,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppText.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final period in periods)
          SizedBox(
            width: _periodColumnWidth,
            child: Center(
              child: _cell(
                row: rowsByPeriod[period.id]?[member.id],
                period: period,
                now: now,
                t: t,
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell({
    required PeriodMemberRow? row,
    required Period period,
    required DateTime now,
    required AppTokens t,
  }) {
    if (row == null) {
      return Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          color: t.softSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.6)),
        ),
        child: Center(
          child: Text('—', style: TextStyle(color: t.textMuted, fontSize: AppText.body)),
        ),
      );
    }

    final overdue = row.isOverdue(now);
    final color = duesStatusColor(t, row.status, overdue: overdue);

    return GestureDetector(
      onTap: () => PaymentDetailSheet.show(context, row: row, period: period),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Icon(
          _statusIcon(row.status, overdue),
          size: 19,
          color: color,
        ),
      ),
    );
  }

  IconData _statusIcon(ChargeStatus status, bool overdue) {
    switch (status) {
      case ChargeStatus.paid:
        return Icons.check_circle_rounded;
      case ChargeStatus.partial:
        return Icons.timelapse_rounded;
      case ChargeStatus.waived:
        return Icons.block_rounded;
      case ChargeStatus.unpaid:
        return overdue ? Icons.warning_rounded : Icons.schedule_rounded;
    }
  }

  Widget _legend(AppTokens t) {
    final partialColor = duesStatusColor(t, ChargeStatus.partial);
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        _legendItem(Icons.check_circle_rounded, t.income, 'Lunas', t),
        _legendItem(Icons.timelapse_rounded, partialColor, 'Dicicil (Sebagian)', t),
        _legendItem(Icons.warning_rounded, t.expense, 'Nunggak (Jatuh Tempo)', t),
        _legendItem(Icons.schedule_rounded, t.textMuted, 'Belum Jatuh Tempo', t),
        _legendItem(Icons.block_rounded, t.textMuted, 'Bebas Iuran', t),
      ],
    );
  }

  Widget _legendItem(
    IconData icon,
    Color color,
    String label,
    AppTokens t,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: AppText.label,
            fontWeight: FontWeight.w500,
            color: t.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parts = label.split(' ');

    return Column(
      children: [
        for (final part in parts)
          Text(
            part,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppText.label,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
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
