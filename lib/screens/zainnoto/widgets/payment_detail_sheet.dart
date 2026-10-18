import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../utils/rupiah_formatter.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';
import 'dues_style.dart';
import 'member_avatar.dart';

typedef _PaymentEditResult = ({int amount, DateTime date, String note});

/// Partial payment dialog that owns its controller, so it is disposed only
/// after the dialog route is fully removed from the tree.
class _PartialPayDialog extends StatefulWidget {
  const _PartialPayDialog({required this.remaining});

  final int remaining;

  @override
  State<_PartialPayDialog> createState() => _PartialPayDialogState();
}

class _PartialPayDialogState extends State<_PartialPayDialog> {
  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: const Text('Bayar Sebagian'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              RupiahInputFormatter(),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              hintText: 'mis. 25.000',
              filled: true,
              fillColor: t.softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sisa tagihan ${formatRupiah(widget.remaining)}. Pembayaran '
            'otomatis mengisi tagihan tertua lebih dulu.',
            style: TextStyle(
              fontSize: AppText.label,
              height: 1.4,
              color: t.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: RupiahInputFormatter.parseClean(_amountCtrl.text) > 0
              ? () => Navigator.pop(
                    context,
                    RupiahInputFormatter.parseClean(_amountCtrl.text),
                  )
              : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Edit payment dialog that owns its controllers and selected date.
class _EditPaymentDialog extends StatefulWidget {
  const _EditPaymentDialog({
    required this.initialAmount,
    required this.initialDate,
    required this.initialNote,
  });

  final int initialAmount;
  final DateTime initialDate;
  final String initialNote;

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  late final TextEditingController _amountCtrl =
      TextEditingController(text: formatRupiah(widget.initialAmount).replaceAll('Rp ', ''));
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote);
  late DateTime _date = widget.initialDate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parsed = RupiahInputFormatter.parseClean(_amountCtrl.text);
    return AlertDialog(
      title: const Text('Ubah Pembayaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              RupiahInputFormatter(),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              hintText: 'mis. 25.000',
              filled: true,
              fillColor: t.softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _date = picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: t.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: t.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatTanggalSingkat(dateToStr(_date)),
                    style: TextStyle(
                      fontSize: AppText.bodyLarge,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              filled: true,
              fillColor: t.softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: parsed > 0
              ? () => Navigator.pop(
                    context,
                    (
                      amount: parsed,
                      date: _date,
                      note: _noteCtrl.text.trim(),
                    ),
                  )
              : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Bottom sheet for one member's charge in one period: status breakdown,
/// payment history with FIFO allocations, and all correction actions.
class PaymentDetailSheet extends StatefulWidget {
  const PaymentDetailSheet({
    super.key,
    required this.row,
    required this.period,
  });

  final PeriodMemberRow row;
  final Period period;

  static Future<void> show(
    BuildContext context, {
    required PeriodMemberRow row,
    required Period period,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PaymentDetailSheet(row: row, period: period),
    );
  }

  @override
  State<PaymentDetailSheet> createState() => _PaymentDetailSheetState();
}

class _PaymentDetailSheetState extends State<PaymentDetailSheet> {
  final Map<String, Future<List<AllocationDetail>>> _allocations = {};
  bool _isProcessing = false;

  PeriodMemberRow get _row => widget.row;

  Future<void> _markPaid(int amount) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final provider = context.read<ZainNotoProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _row.memberName;
    final txId = await provider.markPaid(memberId: _row.memberId, amount: amount);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (txId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mencatat pembayaran')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Pembayaran $name dicatat'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => provider.deleteTransaction(txId),
        ),
      ),
    );
  }

  Future<void> _showPartialDialog() async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _PartialPayDialog(remaining: _row.remaining),
    );
    if (amount == null || !mounted) return;
    await _markPaid(amount);
  }

  Future<void> _showEditDialog(GroupTransaction tx) async {
    final provider = context.read<ZainNotoProvider>();
    final initialDate = DateTime.tryParse(tx.date) ?? DateTime.now();

    final result = await showDialog<_PaymentEditResult>(
      context: context,
      builder: (_) => _EditPaymentDialog(
        initialAmount: tx.amount,
        initialDate: initialDate,
        initialNote: tx.note ?? '',
      ),
    );
    if (result == null || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.editTransaction(
      id: tx.id,
      amount: result.amount,
      date: dateToStr(result.date),
      note: result.note,
    );
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Pembayaran diperbarui' : 'Gagal memperbarui pembayaran',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(GroupTransaction tx) async {
    final provider = context.read<ZainNotoProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pembayaran?'),
        content: Text(
          'Pembayaran ${formatRupiah(tx.amount)} pada '
          '${formatTanggalSingkat(tx.date)} akan dihapus dan alokasinya '
          'dihitung ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.deleteTransaction(tx.id);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Pembayaran dihapus' : 'Gagal menghapus pembayaran'),
      ),
    );
  }

  Future<void> _toggleWaived() async {
    final provider = context.read<ZainNotoProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final waive = !_row.waived;
    final ok = await provider.setChargeWaived(_row.chargeId, waived: waive);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengubah status bebas iuran')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          waive ? 'Ditandai bebas iuran' : 'Bebas iuran dibatalkan',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final row = _row;
    final status = row.status;
    final overdue = row.isOverdue(DateTime.now());
    final statusColor = duesStatusColor(t, status, overdue: overdue);

    final payments = provider.transactions
        .where((tx) => tx.type == TxType.dues && tx.memberId == row.memberId)
        .toList();
    for (final tx in payments) {
      _allocations.putIfAbsent(
        tx.id,
        () => provider.allocationDetailsFor(tx.id),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
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
                  MemberAvatar(
                    name: row.memberName,
                    color: statusColor,
                    size: 46,
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
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.period.label,
                          style: TextStyle(
                            fontSize: AppText.body,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      duesStatusLabel(status),
                      style: TextStyle(
                        fontSize: AppText.label,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: t.softSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _Stat(
                      label: 'Tagihan',
                      value: formatRupiah(row.amountDue),
                      color: t.textPrimary,
                    ),
                    Container(width: 1, height: 30, color: t.border),
                    _Stat(
                      label: 'Terbayar',
                      value: formatRupiah(row.paid),
                      color: t.income,
                    ),
                    Container(width: 1, height: 30, color: t.border),
                    _Stat(
                      label: 'Sisa',
                      value: formatRupiah(row.remaining),
                      color: row.remaining > 0 ? t.expense : t.income,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Riwayat Pembayaran',
                style: TextStyle(
                  fontSize: AppText.bodyLarge,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                Text(
                  'Belum ada pembayaran untuk anggota ini.',
                  style: TextStyle(
                    fontSize: AppText.body,
                    height: 1.4,
                    color: t.textMuted,
                  ),
                )
              else
                for (final tx in payments) ...[
                  _PaymentTile(
                    tx: tx,
                    allocations: _allocations[tx.id]!,
                    onEdit: () => _showEditDialog(tx),
                    onDelete: () => _confirmDelete(tx),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 10),
              if (!row.waived && row.remaining > 0) ...[
                ElevatedButton.icon(
                  onPressed: () => _markPaid(row.remaining),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Tandai Lunas · ${formatRupiah(row.remaining)}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _showPartialDialog,
                  child: const Text('Bayar Sebagian'),
                ),
                const SizedBox(height: 6),
              ],
              if (!row.waived && status != ChargeStatus.paid)
                TextButton(
                  onPressed: _toggleWaived,
                  child: const Text('Tandai Bebas Iuran'),
                ),
              if (row.waived)
                TextButton(
                  onPressed: _toggleWaived,
                  child: const Text('Batalkan Bebas Iuran'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppText.micro,
              fontWeight: FontWeight.w500,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.tx,
    required this.allocations,
    required this.onEdit,
    required this.onDelete,
  });

  final GroupTransaction tx;
  final Future<List<AllocationDetail>> allocations;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatRupiah(tx.amount),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTanggalSingkat(tx.date),
                      style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit transaksi',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: t.textMuted,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus transaksi',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: t.expense,
                ),
              ),
            ],
          ),
          if (tx.note != null && tx.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                tx.note!,
                style: TextStyle(
                  fontSize: AppText.label,
                  height: 1.4,
                  color: t.textMuted,
                ),
              ),
            ),
          ],
          FutureBuilder<List<AllocationDetail>>(
            future: allocations,
            builder: (context, snapshot) {
              final details = snapshot.data;
              if (details == null || details.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final detail in details)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 13,
                              color: t.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${detail.periodLabel} · '
                                '${formatRupiah(detail.amountAllocated)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.label,
                                  color: t.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
