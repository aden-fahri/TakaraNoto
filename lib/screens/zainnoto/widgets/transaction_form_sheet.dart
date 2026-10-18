import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../utils/rupiah_formatter.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';

/// Add/edit bottom sheet for group transactions.
///
/// Dues payments can be corrected here too: the type stays locked and the
/// member is shown read-only, matching the edit-in-place rules.
class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({super.key, this.existing});

  final GroupTransaction? existing;

  static Future<void> show(
    BuildContext context, {
    GroupTransaction? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: TransactionFormSheet(existing: existing),
      ),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late TxType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isDues => widget.existing?.type == TxType.dues;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? TxType.expense;
    _amountCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    _categoryCtrl = TextEditingController(text: existing?.category ?? '');
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _date = DateTime.tryParse(existing?.date ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<ZainNotoProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = RupiahInputFormatter.parseClean(_amountCtrl.text);
    if (amount <= 0) return;

    setState(() => _saving = true);
    final existing = widget.existing;
    final category = _categoryCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    final ok = existing == null
        ? await provider.addTransaction(
            type: _type,
            amount: amount,
            category: category.isEmpty ? null : category,
            note: note.isEmpty ? null : note,
            date: dateToStr(_date),
          ) !=
            null
        : await provider.editTransaction(
            id: existing.id,
            amount: amount,
            date: dateToStr(_date),
            note: note,
            category: _isDues ? null : category,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan transaksi')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Transaksi diperbarui' : 'Transaksi dicatat')),
    );
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final provider = context.read<ZainNotoProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Transaksi ${formatRupiah(existing.amount)} pada '
          '${formatTanggalSingkat(existing.date)} akan dihapus.',
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
    final ok = await provider.deleteTransaction(existing.id);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus transaksi')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = context.watch<ZainNotoProvider>();
    final member = provider.memberById(widget.existing?.memberId);
    final amount = int.tryParse(_amountCtrl.text) ?? 0;

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
              Text(
                _isEdit ? 'Ubah Transaksi' : 'Catat Transaksi',
                style: TextStyle(
                  fontSize: AppText.title,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (!_isEdit) ...[
                Row(
                  children: [
                    Expanded(
                      child: _TypePill(
                        label: 'Keluar',
                        icon: Icons.arrow_upward_rounded,
                        color: t.expense,
                        selected: _type == TxType.expense,
                        onTap: () => setState(() => _type = TxType.expense),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypePill(
                        label: 'Masuk',
                        icon: Icons.arrow_downward_rounded,
                        color: t.income,
                        selected: _type == TxType.otherIncome,
                        onTap: () =>
                            setState(() => _type = TxType.otherIncome),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              if (_isDues && member != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 16,
                        color: t.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Iuran · ${member.name}',
                        style: TextStyle(
                          fontSize: AppText.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _amountCtrl,
                autofocus: !_isEdit,
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
              if (!_isDues) ...[
                TextField(
                  controller: _categoryCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Kategori (opsional)',
                    hintText: 'mis. Konsumsi, Sewa',
                    filled: true,
                    fillColor: t.softSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
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
                        style: TextStyle(fontSize: AppText.bodyLarge, color: t.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                textCapitalization: TextCapitalization.sentences,
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: amount > 0 && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: Text(
                    'Hapus Transaksi',
                    style: TextStyle(
                      color: t.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? color : t.textMuted;

    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : t.softSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppText.bodyLarge,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
