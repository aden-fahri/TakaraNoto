import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'manage_categories_modal.dart';

class AddTransactionModal extends StatefulWidget {
  final FinanceTransaction? editTransaction;
  final String walletType;
  const AddTransactionModal({super.key, this.editTransaction, this.walletType = 'main'});

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late AnimationController _toggleAnim;
  late Animation<double> _pillSlide;

  String _type = 'expense';
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  int? _selectedSavingsGoalId;

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pillSlide = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _toggleAnim, curve: Curves.easeInOut),
    );

    if (widget.walletType == 'topup') {
      _type = 'expense';
    }

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _type = tx.type;
      _selectedCategoryId = tx.categoryId;
      _noteCtrl.text = tx.note;
      _selectedDate = DateTime.parse(tx.date);
      _amountCtrl.text = NumberFormat.decimalPattern('id').format(tx.amount);
      _selectedSavingsGoalId = tx.savingsGoalId;
      if (_type == 'income') _toggleAnim.forward();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _toggleAnim.dispose();
    super.dispose();
  }

  void _onAmountChanged(String text) {
    if (text.isEmpty) return;
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) { _amountCtrl.text = ''; return; }
    final formatted = NumberFormat.decimalPattern('id').format(double.parse(clean));
    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _setType(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _selectedCategoryId = null;
    });
    if (type == 'income') {
      _toggleAnim.forward();
    } else {
      _toggleAnim.reverse();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _save() {
    final clean = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(clean);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid!')),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu!')),
      );
      return;
    }
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Resolve savings goal if the selected category is "Tabungan" (expense)
    final selectedCat = provider.categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(name: '', icon: '', color: '', type: 'expense'),
    );
    final isTabungan = selectedCat.name == 'Tabungan' && selectedCat.type == 'expense';

    // Selecting "Top Up" (expense, main wallet) records a paired wallet
    // transfer instead of a regular expense.
    final isTopUpTransfer = widget.editTransaction == null &&
        widget.walletType == 'main' &&
        _type == 'expense' &&
        selectedCat.name == 'Top Up';
    if (isTopUpTransfer) {
      provider.makeTransfer(
        toTopup: true,
        amount: amount,
        date: dateStr,
        note: _noteCtrl.text.trim(),
      );
      Navigator.pop(context);
      return;
    }

    int? finalGoalId;
    if (isTabungan && provider.savingsGoals.isNotEmpty) {
      finalGoalId = _selectedSavingsGoalId ?? provider.savingsGoals.first.id;
    }

    if (widget.editTransaction != null) {
      provider.updateTx(
        id: widget.editTransaction!.id!,
        categoryId: _selectedCategoryId!,
        amount: amount,
        type: _type,
        date: dateStr,
        note: _noteCtrl.text.trim(),
        savingsGoalId: finalGoalId,
        walletType: widget.walletType,
      );
    } else {
      provider.addTx(
        categoryId: _selectedCategoryId!,
        amount: amount,
        type: _type,
        date: dateStr,
        note: _noteCtrl.text.trim(),
        savingsGoalId: finalGoalId,
        walletType: widget.walletType,
      );
    }
    Navigator.pop(context);
  }

  void _delete() {
    if (widget.editTransaction?.id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Provider.of<FinanceProvider>(context, listen: false)
                  .deleteTx(widget.editTransaction!.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Hapus', style: TextStyle(color: ctx.tokens.expense)),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
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
      default: return Icons.more_horiz_rounded;
    }
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  // ─── Read-only view for paired transfer transactions ───────────────────────
  Widget _buildTransferDetail(BuildContext context, FinanceProvider provider) {
    final tokens = context.tokens;
    final tx = widget.editTransaction!;
    const transferColor = Color(0xFF3f51b5);

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.softSurface,
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      ),
                      child: Icon(Icons.close_rounded, size: 18,
                          color: tokens.textPrimary),
                    ),
                  ),
                  Text('Detail Transfer', style: Theme.of(context).textTheme.titleMedium),
                  GestureDetector(
                    onTap: _delete,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.expense.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      ),
                      child: Icon(Icons.delete_outline_rounded, size: 18, color: tokens.expense),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: transferColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz_rounded, size: 30, color: transferColor),
            ),
            const SizedBox(height: 14),
            Text(
              tx.displayName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.formatCurrency(tx.amount),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: transferColor),
            ),
            const SizedBox(height: 6),
            Text(
              tx.date,
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
            if (tx.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  tx.note,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: transferColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: transferColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: transferColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transfer antar dompet tidak dihitung sebagai pemasukan atau pengeluaran. Menghapus transaksi ini akan menghapus kedua sisi pasangan transfer.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: transferColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final provider = Provider.of<FinanceProvider>(context);

    if (widget.editTransaction?.isTransfer == true) {
      return _buildTransferDetail(context, provider);
    }

    final typeColor = _type == 'income' ? tokens.income : tokens.expense;
    final filteredCats = provider.categories
        .where((c) => c.type == _type)
        .where((c) => c.name != 'Transfer Masuk')
        .where((c) => widget.editTransaction == null || c.name != 'Top Up')
        .where((c) => widget.walletType == 'topup' ? (c.name != 'Top Up' && c.name != 'Tabungan' && c.name != 'Tarik Tabungan') : true)
        .toList();
    if (_selectedCategoryId == null && filteredCats.isNotEmpty) {
      _selectedCategoryId = filteredCats.first.id;
    } else if (_selectedCategoryId != null && !filteredCats.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = filteredCats.isNotEmpty ? filteredCats.first.id : null;
    }
    final selectedCatInfo = provider.categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(name: '', icon: '', color: '', type: 'expense'),
    );
    final isTopUpTransfer = widget.editTransaction == null &&
        widget.walletType == 'main' &&
        _type == 'expense' &&
        selectedCatInfo.name == 'Top Up';
    final borderCol = tokens.border;
    final modalBg = tokens.card;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: borderCol,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.softSurface,
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      ),
                      child: Icon(Icons.close_rounded, size: 18,
                          color: tokens.textPrimary),
                    ),
                  ),
                  Text(
                    widget.editTransaction != null ? 'Ubah Transaksi' : 'Catat Transaksi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  widget.editTransaction != null
                      ? GestureDetector(
                          onTap: _delete,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.expense.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                            ),
                            child: Icon(Icons.delete_outline_rounded, size: 18, color: tokens.expense),
                          ),
                        )
                      : const SizedBox(width: 34),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Animated type toggle
            if (widget.walletType != 'topup') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AnimatedTypeToggle(
                  type: _type,
                  pillSlide: _pillSlide,
                  onChanged: _setType,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Scrollable form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount input
                    Text(
                      'Nominal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: typeColor, width: 2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Rp',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              autofocus: widget.editTransaction == null,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textMuted.withValues(alpha: 0.4),
                                ),
                              ),
                              onChanged: _onAmountChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.textMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ManageCategoriesModal(initialType: _type),
                            );
                          },
                          child: Text(
                            'Kelola Kategori',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Category grid (4 per row)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredCats.length,
                      itemBuilder: (_, i) {
                        final cat = filteredCats[i];
                        final isSelected = _selectedCategoryId == cat.id;
                        final color = _parseColor(cat.color);

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategoryId = cat.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : tokens.softSurface,
                              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: color,
                                  child: Icon(_getIconData(cat.icon), color: Colors.white, size: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? color
                                        : tokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    if (isTopUpTransfer) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3f51b5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3f51b5).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF3f51b5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dicatat sebagai Transfer ke Dompet E-Wallet, tidak dihitung sebagai pengeluaran.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF3f51b5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Savings Goal Selector (only if type is expense and category is 'Tabungan')
                    (() {
                      final selectedCat = provider.categories.firstWhere(
                        (c) => c.id == _selectedCategoryId,
                        orElse: () => Category(name: '', icon: '', color: '', type: 'expense'),
                      );
                      final isTabungan = selectedCat.name == 'Tabungan' && selectedCat.type == 'expense';
                      if (!isTabungan) return const SizedBox.shrink();

                      final goals = provider.savingsGoals;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Tabungan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          goals.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: tokens.expense.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.expense.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 16, color: tokens.expense),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Belum ada target tabungan. Silakan buat target di tab Tabungan terlebih dahulu.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: tokens.expense,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: tokens.softSurface,
                                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                    border: Border.all(color: borderCol, width: 0.5),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedSavingsGoalId != null &&
                                              goals.any((g) => g.id == _selectedSavingsGoalId)
                                          ? _selectedSavingsGoalId
                                          : (goals.isNotEmpty ? goals.first.id : null),
                                      isExpanded: true,
                                      dropdownColor: modalBg,
                                      icon: Icon(Icons.arrow_drop_down_rounded,
                                          color: tokens.textPrimary),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                      onChanged: (int? value) {
                                        setState(() => _selectedSavingsGoalId = value);
                                      },
                                      items: goals.map((g) {
                                        return DropdownMenuItem<int>(
                                          value: g.id,
                                          child: Text('${g.title} (${provider.formatCurrency(g.currentAmount)} / ${provider.formatCurrency(g.targetAmount)})'),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 20),
                        ],
                      );
                    })(),

                    // Date chip
                    Text(
                      'Tanggal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: tokens.softSurface,
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 18,
                                color: tokens.textMuted),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd MMM yyyy', 'id').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Note input
                    Text(
                      'Catatan (Opsional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tambahkan catatan...',
                        fillColor: tokens.softSurface,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Save button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderCol, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: typeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    'Simpan Transaksi',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Type Toggle ──────────────────────────────────────────────────────
class _AnimatedTypeToggle extends StatelessWidget {
  final String type;
  final Animation<double> pillSlide;
  final ValueChanged<String> onChanged;

  const _AnimatedTypeToggle({
    required this.type,
    required this.pillSlide,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.softSurface,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      ),
      child: Stack(
        children: [
          // Animated pill
          AnimatedBuilder(
            animation: pillSlide,
            builder: (context, _) => Align(
              alignment: Alignment(pillSlide.value * 2 - 1, 0),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: pillSlide.value < 0.5 ? tokens.expense : tokens.income,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (pillSlide.value < 0.5 ? tokens.expense : tokens.income)
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('expense'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 14,
                            color: type == 'expense' ? Colors.white : Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          'Pengeluaran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: type == 'expense' ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('income'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 14,
                            color: type == 'income' ? Colors.white : Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          'Pemasukan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: type == 'income' ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
