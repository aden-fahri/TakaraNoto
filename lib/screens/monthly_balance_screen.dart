import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class MonthlyBalanceScreen extends StatelessWidget {
  const MonthlyBalanceScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final history = provider.monthlyNetHistory;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double grandTotalBalance = history.fold(0.0, (sum, item) => sum + (item['balance'] as double));
    final totalColor = grandTotalBalance >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed;

    final bannerBg = isDark ? AppTheme.deepPlum : AppTheme.darkPlum;
    final cardBg = isDark ? AppTheme.lighterPlum : Colors.white;
    final borderCol = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepPlum : AppTheme.warmCream,
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
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.warmCream),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Riwayat Saldo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warmCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cumulative Net Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Akumulasi Saldo Bersih',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedDarkLavender,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              provider.formatCurrency(grandTotalBalance),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: totalColor,
                              ),
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

          // ─── SCROLLABLE HISTORY LIST ────────────────────────────────────────
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHeroLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderCol),
                          ),
                          child: const Icon(Icons.history_toggle_off_rounded, size: 32, color: AppTheme.mutedLightPlum),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada riwayat bulanan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppTheme.warmCream : AppTheme.darkPlum),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final monthStr = item['month'] as String;
                      final inc = item['income'] as double;
                      final exp = item['expense'] as double;
                      final bal = item['balance'] as double;
                      final balColor = bal >= 0 ? AppTheme.emeraldGreen : AppTheme.roseRed;

                      return Card(
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _monthName(monthStr),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTheme.warmCream : AppTheme.darkPlum,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: balColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: balColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      '${bal >= 0 ? '+' : ''}${provider.formatCurrency(bal)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: balColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Divider(height: 1, thickness: 0.5, color: borderCol),
                              const SizedBox(height: 14),

                              // Income & Expense Breakdown
                              Row(
                                children: [
                                  // Income details
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.emeraldGreen, size: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Masuk',
                                                style: TextStyle(fontSize: 10, color: AppTheme.mutedLightPlum, fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                provider.formatCurrency(inc),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AppTheme.warmCream : AppTheme.darkPlum,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Spacer
                                  Container(width: 1, height: 24, color: borderCol, margin: const EdgeInsets.symmetric(horizontal: 8)),
                                  // Expense details
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppTheme.roseRed.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.arrow_upward_rounded, color: AppTheme.roseRed, size: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Keluar',
                                                style: TextStyle(fontSize: 10, color: AppTheme.mutedLightPlum, fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                provider.formatCurrency(exp),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AppTheme.warmCream : AppTheme.darkPlum,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
