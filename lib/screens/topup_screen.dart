import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/add_transaction_modal.dart';

class TopupScreen extends StatelessWidget {
  const TopupScreen({super.key});

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionModal(walletType: 'topup'),
    );
  }

  void _showTransferDialog(BuildContext context, bool toTopup) {
    showDialog(
      context: context,
      builder: (_) => _WalletTransferDialog(toTopup: toTopup),
    );
  }

  void _showEditExpense(BuildContext context, FinanceTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(editTransaction: tx, walletType: 'topup'),
    );
  }

  IconData _icon(String name) {
    switch (name) {
      case 'fast_food': return Icons.fastfood_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'cart': return Icons.shopping_cart_rounded;
      case 'gamepad_2': return Icons.sports_esports_rounded;
      case 'heart_pulse': return Icons.favorite_rounded;
      case 'receipt': return Icons.receipt_long_rounded;
      case 'banknote': return Icons.payments_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'gift': return Icons.redeem_rounded;
      case 'payments': return Icons.payments_rounded;
      case 'download': return Icons.download_rounded;
      case 'ellipsis': return Icons.more_horiz_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  Color _color(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);
    final txs = provider.topupTransactions;
    final balance = provider.topupBalance;

    final bannerBg = tokens.headerBg;
    final cardBg = tokens.card;
    final borderCol = tokens.border;

    return Scaffold(
      backgroundColor: tokens.pageBg,
      body: Column(
        children: [
          // ─── PLUM BANNER ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button & Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.headerSurface,
                              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                              border: Border.all(color: tokens.headerBorder, width: 1),
                            ),
                            child: Icon(Icons.arrow_back_rounded, size: 18, color: tokens.headerFg),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Dompet E-Wallet',
                          style: TextStyle(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w800,
                            color: tokens.headerFg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tokens.headerSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tokens.headerBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Saldo E-Wallet Saat Ini',
                                style: TextStyle(
                                  fontSize: AppText.body,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.headerMuted,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.stars_rounded, size: 10, color: Color(0xFFFFB300)),
                                    SizedBox(width: 4),
                                    Text('E-Money', style: TextStyle(fontSize: AppText.micro, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              provider.formatCurrency(balance),
                              style: TextStyle(
                                fontSize: AppText.stat,
                                fontWeight: FontWeight.w800,
                                color: tokens.headerFg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.headerFg,
                                    foregroundColor: tokens.headerBg,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    elevation: 2,
                                    textStyle: const TextStyle(fontSize: AppText.micro, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () => _showTransferDialog(context, true),
                                  icon: const Icon(Icons.add_rounded, size: 14),
                                  label: const Text('Isi Saldo'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tokens.headerFg,
                                    side: BorderSide(color: tokens.headerBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    textStyle: const TextStyle(fontSize: AppText.micro, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () => _showTransferDialog(context, false),
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                                  label: const Text('Tarik'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: tokens.headerFg,
                                    side: BorderSide(color: tokens.headerBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    textStyle: const TextStyle(fontSize: AppText.micro, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () => _showAddExpense(context),
                                  icon: const Icon(Icons.shopping_cart_rounded, size: 14),
                                  label: const Text('Keluar'),
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
            ),
          ),

          // ─── TRANSACTION HISTORY LIST ────────────────────────────────────────
          Expanded(
            child: txs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: tokens.softSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderCol),
                            ),
                            child: Icon(Icons.receipt_long_outlined, size: 32, color: tokens.textMuted),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada transaksi e-wallet',
                            style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tekan "Isi Saldo" untuk menambah saldo dari dompet utama, atau gunakan kategori "Top Up" di Dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: AppText.body, color: tokens.textMuted, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: txs.length,
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final catColor = _color(tx.categoryColor ?? '#95a5a6');
                      final isAdd = tx.type == 'income'; // Force display as income if it is a topup addition
                      final txColor = isAdd ? tokens.income : tokens.expense;
                      final sign = isAdd ? '+' : '-';

                      return Card(
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _showEditExpense(context, tx),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Category Icon
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: catColor.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: catColor,
                                    child: Icon(_icon(tx.categoryIcon ?? ''), color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.displayName,
                                        style: TextStyle(
                                          fontSize: AppText.bodyLarge,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      if (tx.note.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tx.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: AppText.label, color: tokens.textMuted),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        tx.date,
                                        style: TextStyle(fontSize: AppText.micro, color: tokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),

                                // Amount
                                Text(
                                  '$sign ${provider.formatCurrency(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: AppText.bodyLarge,
                                    fontWeight: FontWeight.w800,
                                    color: txColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: Transfer funds between main wallet and e-wallet ─────────────────
class _WalletTransferDialog extends StatefulWidget {
  final bool toTopup;
  const _WalletTransferDialog({required this.toTopup});

  @override
  State<_WalletTransferDialog> createState() => _WalletTransferDialogState();
}

class _WalletTransferDialogState extends State<_WalletTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  bool get _toTopup => widget.toTopup;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String text) {
    if (text.isEmpty) return;
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      _amountCtrl.text = '';
      return;
    }
    final formatted = NumberFormat.decimalPattern('id').format(double.parse(clean));
    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid!')),
      );
      return;
    }

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (!_toTopup && amount > provider.topupBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo e-wallet tidak cukup! Maksimal: ${provider.formatCurrency(provider.topupBalance)}',
          ),
        ),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty
        ? (_toTopup ? 'Isi saldo e-wallet' : 'Tarik saldo ke dompet utama')
        : _noteCtrl.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    provider.makeTransfer(
      toTopup: _toTopup,
      amount: amount,
      date: dateStr,
      note: note,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toTopup
              ? 'Berhasil mengisi saldo e-wallet ${provider.formatCurrency(amount)}!'
              : 'Berhasil menarik ${provider.formatCurrency(amount)} ke dompet utama!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const transferColor = Color(0xFF3f51b5);

    return AlertDialog(
      title: Text(_toTopup ? 'Isi Saldo E-Wallet' : 'Tarik ke Dompet Utama'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: transferColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: transferColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 16, color: transferColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _toTopup
                            ? 'Dana berpindah dari dompet utama ke E-Wallet, bukan pengeluaran.'
                            : 'Dana kembali ke dompet utama, bukan pemasukan.',
                        style: const TextStyle(fontSize: AppText.label, color: transferColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nominal (Rp)',
                style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(fontSize: AppText.title, color: tokens.textPrimary, fontWeight: FontWeight.w700),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: tokens.softSurface.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: transferColor, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Tanggal',
                style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.softSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: tokens.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy', 'id').format(_date),
                        style: TextStyle(fontSize: AppText.bodyLarge, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Catatan (Opsional)',
                style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600, color: tokens.textMuted),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                style: TextStyle(fontSize: AppText.subtitle, color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: _toTopup ? 'Misal: Top up untuk bayar online' : 'Misal: Sisa saldo ditarik',
                  fillColor: tokens.softSurface.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: transferColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: transferColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            _toTopup ? 'Isi Saldo' : 'Tarik',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
