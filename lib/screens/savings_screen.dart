import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/savings_goal.dart';
import '../theme/app_theme.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  String _monthName(String s) {
    if (s.isEmpty) return '';
    try {
      final p = s.split('-');
      const names = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${names[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) {
      return s;
    }
  }

  void _showAddGoalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddSavingsGoalDialog(),
    );
  }

  void _showEditGoalDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => _EditSavingsGoalDialog(goal: goal),
    );
  }

  void _showAddSavingDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => _AddSavingFundsDialog(goal: goal),
    );
  }

  void _showWithdrawDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => _WithdrawFundsDialog(goal: goal),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Target Tabungan'),
        content: Text('Apakah Anda yakin ingin menghapus target "${goal.title}"? Transaksi yang terkait akan tetap ada namun tidak terhubung lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<FinanceProvider>(context, listen: false)
                  .deleteSavingsGoal(goal.id!);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Target "${goal.title}" berhasil dihapus.')),
              );
            },
            child: const Text('Hapus', style: TextStyle(color: AppTheme.roseRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionText(BuildContext context, SavingsGoal goal) {
    final currentAmount = goal.currentAmount;
    final targetAmount = goal.targetAmount;

    if (currentAmount >= targetAmount) {
      return const Row(
        children: [
          Icon(Icons.stars_rounded, size: 16, color: AppTheme.emeraldGreen),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Selamat! Target tabungan Anda sudah tercapai! 🎉',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.emeraldGreen,
              ),
            ),
          ),
        ],
      );
    }

    // Parse creation date
    DateTime createdDate;
    try {
      createdDate = DateTime.parse(goal.createdAt);
    } catch (_) {
      createdDate = DateTime.now();
    }

    final today = DateTime.now();
    // Calculate difference in days, at least 1 day to avoid division by zero
    final diffDays = max(1, today.difference(createdDate).inDays);
    final dailySavingRate = currentAmount / diffDays;

    if (currentAmount <= 0 || dailySavingRate <= 0) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.mutedLightPlum.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Belum ada tabungan. Mulai menabung secara konsisten untuk melihat perkiraan selesai!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedLightPlum,
              ),
            ),
          ),
        ],
      );
    }

    final remainingAmount = targetAmount - currentAmount;
    final daysRemaining = (remainingAmount / dailySavingRate).ceil();
    final projectedDate = today.add(Duration(days: daysRemaining));
    final formattedDate = DateFormat('d MMMM yyyy', 'id').format(projectedDate);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.mutedLightPlum),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mutedLightPlum,
                height: 1.3,
              ),
              children: [
                const TextSpan(text: 'Jika konsisten, target akan tercapai dalam '),
                TextSpan(
                  text: '$daysRemaining hari lagi',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkPlum),
                ),
                const TextSpan(text: ' (pada '),
                TextSpan(
                  text: formattedDate,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkPlum),
                ),
                const TextSpan(text: ')'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final goals = provider.savingsGoals;
    final currentMonth = provider.currentMonth;

    final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalSavings = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    final totalProgressPct = totalTarget > 0 ? (totalSavings / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ PLUM BANNER ═══════════════════════════════════════════════════
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.darkPlum,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _monthName(currentMonth),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedDarkLavender,
                          ),
                        ),
                        const Text(
                          'Tabungan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warmCream,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: AppTheme.mutedDarkLavender),
                          const SizedBox(width: 6),
                          Text(
                            '${goals.length} Target',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedDarkLavender,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ══ SCROLLABLE CONTENT ════════════════════════════════════════════
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.darkPlum))
                : RefreshIndicator(
                    color: AppTheme.darkPlum,
                    onRefresh: provider.refreshAll,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Summary card (total target vs total savings)
                        if (goals.isNotEmpty) ...[
                          _SavingsSummaryCard(
                            totalTarget: totalTarget,
                            totalSavings: totalSavings,
                            progressPct: totalProgressPct,
                            provider: provider,
                          ),
                          const SizedBox(height: 24),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target Impian Saya',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        goals.isEmpty
                            ? _EmptySavingsState(onAdd: () => _showAddGoalDialog(context))
                            : Column(
                                children: goals.map((goal) {
                                  final pct = goal.targetAmount > 0
                                      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                                      : 0.0;
                                  final pctText = '${(pct * 100).toStringAsFixed(1)}%';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.borderLight, width: 1),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onLongPress: () => _showDeleteConfirmDialog(context, goal),
                                          child: Padding(
                                            padding: const EdgeInsets.all(18),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Header: Title & Edit & Trash icon
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        goal.title,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppTheme.darkPlum,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () => _showEditGoalDialog(context, goal),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: AppTheme.mutedLightPlum,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    IconButton(
                                                      onPressed: () => _showDeleteConfirmDialog(context, goal),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      icon: const Icon(
                                                        Icons.delete_outline_rounded,
                                                        size: 18,
                                                        color: AppTheme.roseRed,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),

                                                // Progress label
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '${provider.formatCurrency(goal.currentAmount)} dari ${provider.formatCurrency(goal.targetAmount)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.mutedLightPlum,
                                                      ),
                                                    ),
                                                    Text(
                                                      pctText,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        color: pct >= 1.0 ? AppTheme.emeraldGreen : AppTheme.darkPlum,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),

                                                // Progress bar
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(5),
                                                  child: LinearProgressIndicator(
                                                    value: pct,
                                                    minHeight: 8,
                                                    backgroundColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.5),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      pct >= 1.0
                                                          ? AppTheme.emeraldGreen
                                                          : pct >= 0.5
                                                              ? AppTheme.selectedPlum
                                                              : AppTheme.amberAccent,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 14),

                                                // Projection info
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.warmCream.withValues(alpha: 0.6),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.5), width: 0.5),
                                                  ),
                                                  child: _buildProjectionText(context, goal),
                                                ),
                                                const SizedBox(height: 12),

                                                // Action buttons row
                                                Row(
                                                  children: [
                                                    // Tarik Dana button
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: goal.currentAmount > 0
                                                            ? () => _showWithdrawDialog(context, goal)
                                                            : null,
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: AppTheme.roseRed,
                                                          side: BorderSide(
                                                            color: goal.currentAmount > 0
                                                                ? AppTheme.roseRed.withValues(alpha: 0.6)
                                                                : AppTheme.borderLight,
                                                          ),
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                        icon: Icon(
                                                          Icons.arrow_upward_rounded,
                                                          size: 14,
                                                          color: goal.currentAmount > 0
                                                              ? AppTheme.roseRed
                                                              : AppTheme.mutedLightPlum,
                                                        ),
                                                        label: Text(
                                                          'Tarik Dana',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: goal.currentAmount > 0
                                                                ? AppTheme.roseRed
                                                                : AppTheme.mutedLightPlum,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    // Isi Saldo button
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => _showAddSavingDialog(context, goal),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppTheme.darkPlum,
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                        icon: const Icon(Icons.add_rounded, size: 14),
                                                        label: const Text(
                                                          'Isi Saldo',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context),
        backgroundColor: AppTheme.darkPlum,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Target Baru', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 3,
      ),
    );
  }
}

// ─── Savings Summary Card ────────────────────────────────────────────────────
class _SavingsSummaryCard extends StatelessWidget {
  final double totalTarget;
  final double totalSavings;
  final double progressPct;
  final FinanceProvider provider;

  const _SavingsSummaryCard({
    required this.totalTarget,
    required this.totalSavings,
    required this.progressPct,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkPlum,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Tabungan Saya',
            style: TextStyle(
              color: AppTheme.mutedDarkLavender,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.formatCurrency(totalSavings),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withValues(alpha: 0.15)),
                FractionallySizedBox(
                  widthFactor: progressPct,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(progressPct * 100).toStringAsFixed(1)}% dari target total',
                style: const TextStyle(color: AppTheme.mutedDarkLavender, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Target: ${provider.formatCurrency(totalTarget)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedDarkLavender,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptySavingsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySavingsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.4),
                child: const Icon(
                  Icons.savings_outlined,
                  size: 40,
                  color: AppTheme.mutedLightPlum,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.darkPlum,
                  child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum Ada Target Tabungan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkPlum,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mulai buat target impian Anda dan pantau kemajuannya di sini!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mutedLightPlum,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkPlum,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buat Target Pertama'),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: Add Savings Goal ────────────────────────────────────────────────
class _AddSavingsGoalDialog extends StatefulWidget {
  const _AddSavingsGoalDialog();

  @override
  State<_AddSavingsGoalDialog> createState() => _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends State<_AddSavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal target yang valid!')),
      );
      return;
    }

    final title = _titleCtrl.text.trim();

    Provider.of<FinanceProvider>(context, listen: false).addSavingsGoal(
      title: title,
      targetAmount: amount,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Target "$title" berhasil ditambahkan!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Target Tabungan Baru'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Target',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum),
                decoration: InputDecoration(
                  hintText: 'Misal: Beli Laptop Baru',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama target tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Nominal Target (Rp)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum, fontWeight: FontWeight.w700),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal target tidak boleh kosong';
                  }
                  return null;
                },
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
            backgroundColor: AppTheme.darkPlum,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Buat Target', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: Add Saving Funds ────────────────────────────────────────────────
class _AddSavingFundsDialog extends StatefulWidget {
  final SavingsGoal goal;
  const _AddSavingFundsDialog({required this.goal});

  @override
  State<_AddSavingFundsDialog> createState() => _AddSavingFundsDialogState();
}

class _AddSavingFundsDialogState extends State<_AddSavingFundsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal uang yang valid!')),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty ? 'Isi saldo target "${widget.goal.title}"' : _noteCtrl.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Provider.of<FinanceProvider>(context, listen: false).addSavingTransaction(
      goalId: widget.goal.id!,
      amount: amount,
      note: note,
      date: dateStr,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Berhasil menyetor Rp ${_amountCtrl.text} ke "${widget.goal.title}"!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Isi Saldo: ${widget.goal.title}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nominal Setoran (Rp)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: AppTheme.darkPlum, fontWeight: FontWeight.w700),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal setoran tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Catatan (Opsional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum),
                decoration: InputDecoration(
                  hintText: 'Misal: Sisa uang belanja mingguan',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
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
            backgroundColor: AppTheme.darkPlum,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: Withdraw Funds ──────────────────────────────────────────────────
class _WithdrawFundsDialog extends StatefulWidget {
  final SavingsGoal goal;
  const _WithdrawFundsDialog({required this.goal});

  @override
  State<_WithdrawFundsDialog> createState() => _WithdrawFundsDialogState();
}

class _WithdrawFundsDialogState extends State<_WithdrawFundsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal penarikan yang valid!')),
      );
      return;
    }

    if (amount > widget.goal.currentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saldo tidak cukup! Maksimal penarikan: ${NumberFormat.decimalPattern('id').format(widget.goal.currentAmount)}')),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty
        ? 'Tarik dana dari "${widget.goal.title}"'
        : _noteCtrl.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Provider.of<FinanceProvider>(context, listen: false).withdrawSavingTransaction(
      goalId: widget.goal.id!,
      amount: amount,
      note: note,
      date: dateStr,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Berhasil menarik Rp ${_amountCtrl.text} dari "${widget.goal.title}"!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tarik Dana: ${widget.goal.title}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saldo available info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.roseRed.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.roseRed.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppTheme.roseRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: AppTheme.mutedLightPlum),
                          children: [
                            const TextSpan(text: 'Saldo tersedia: '),
                            TextSpan(
                              text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                                  .format(widget.goal.currentAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.roseRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nominal Penarikan (Rp)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: AppTheme.roseRed, fontWeight: FontWeight.w700),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.roseRed, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal penarikan tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Catatan (Opsional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum),
                decoration: InputDecoration(
                  hintText: 'Misal: Dipakai untuk keperluan darurat',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.roseRed, width: 1.5),
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
            backgroundColor: AppTheme.roseRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Tarik', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: Edit Savings Goal ────────────────────────────────────────────────
class _EditSavingsGoalDialog extends StatefulWidget {
  final SavingsGoal goal;
  const _EditSavingsGoalDialog({required this.goal});

  @override
  State<_EditSavingsGoalDialog> createState() => _EditSavingsGoalDialogState();
}

class _EditSavingsGoalDialogState extends State<_EditSavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.goal.title);
    _amountCtrl = TextEditingController(
      text: NumberFormat.decimalPattern('id').format(widget.goal.targetAmount),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal target yang valid!')),
      );
      return;
    }

    final title = _titleCtrl.text.trim();

    Provider.of<FinanceProvider>(context, listen: false).updateSavingsGoal(
      id: widget.goal.id!,
      title: title,
      targetAmount: amount,
      createdAt: widget.goal.createdAt,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Target "$title" berhasil diperbarui!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Target Tabungan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Target',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum),
                decoration: InputDecoration(
                  hintText: 'Misal: Beli Laptop Baru',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama target tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Nominal Target (Rp)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mutedLightPlum),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: AppTheme.darkPlum, fontWeight: FontWeight.w700),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: AppTheme.surfaceHeroLight.withValues(alpha: 0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkPlum, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nominal target tidak boleh kosong';
                  }
                  return null;
                },
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
            backgroundColor: AppTheme.darkPlum,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

