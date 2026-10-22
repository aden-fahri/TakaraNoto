import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../utils/rupiah_formatter.dart';
import '../../../zainnoto/models/derived.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';

class PayDuesSheet extends StatefulWidget {
  const PayDuesSheet({super.key, required this.row, required this.period});

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PayDuesSheet(row: row, period: period),
    );
  }

  @override
  State<PayDuesSheet> createState() => _PayDuesSheetState();
}

class _PayDuesSheetState extends State<PayDuesSheet> {
  late final TextEditingController _amountCtrl = TextEditingController(
    text: RupiahInputFormatter.format(widget.row.remaining),
  );
  final TextEditingController _noteCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  late DateTime _date;
  bool _saving = false;

  int get _amount => RupiahInputFormatter.parseClean(_amountCtrl.text);

  @override
  void initState() {
    super.initState();
    _date = dateOnly(context.read<ZainNotoProvider>().now);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (amount <= 0 || _saving) return;
    setState(() => _saving = true);
    final provider = context.read<ZainNotoProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final name = widget.row.memberName;
    final note = _noteCtrl.text.trim();

    final txId = await provider.markPaid(
      memberId: widget.row.memberId,
      amount: amount,
      date: dateToStr(_date),
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (txId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mencatat pembayaran')),
      );
      return;
    }
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = widget.row;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bayar iuran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${row.memberName} · tagihan ${widget.period.label}',
                style: TextStyle(
                  fontSize: AppText.body,
                  color: t.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('zn-pay-amount'),
                controller: _amountCtrl,
                focusNode: _amountFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Jumlah bayar',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: t.softSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total tagihan',
                style: TextStyle(
                  fontSize: AppText.body,
                  color: t.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AmountChip(
                      chipKey: const ValueKey('zn-pay-chip-all'),
                      label: 'Lunasi semua',
                      selected: _amount == row.remaining && _amount > 0,
                      onTap: () {
                        _amountCtrl.text =
                            RupiahInputFormatter.format(row.remaining);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AmountChip(
                      chipKey: const ValueKey('zn-pay-chip-due'),
                      label: formatRupiah(row.amountDue),
                      selected: _amount == row.amountDue &&
                          _amount != row.remaining,
                      onTap: () {
                        _amountCtrl.text =
                            RupiahInputFormatter.format(row.amountDue);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AmountChip(
                      chipKey: const ValueKey('zn-pay-chip-partial'),
                      label: 'Cicil',
                      selected: _amount != row.remaining &&
                          _amount != row.amountDue,
                      onTap: () => _amountFocus.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                key: const ValueKey('zn-pay-date'),
                behavior: HitTestBehavior.opaque,
                onTap: _pickDate,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: t.pageBg,
                    border: Border.all(color: t.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        formatTanggalSingkat(dateToStr(_date)),
                        style: TextStyle(
                          fontSize: AppText.bodyLarge,
                          fontWeight: FontWeight.w500,
                          color: t.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: t.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('zn-pay-note'),
                controller: _noteCtrl,
                style: TextStyle(
                  fontSize: AppText.bodyLarge,
                  color: t.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Transfer atau tunai',
                  filled: true,
                  fillColor: t.softSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.softSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Dibayar lebih dari tagihan akan menjadi kredit dan otomatis '
                  'dipakai di periode berikutnya.',
                  style: TextStyle(
                    fontSize: AppText.body,
                    height: 1.6,
                    color: t.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('zn-pay-submit'),
                  onPressed: _amount > 0 && !_saving ? _submit : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Catat pembayaran'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      key: chipKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? t.softSurfaceStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? t.accent : t.border,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w600,
              color: selected ? t.textPrimary : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
