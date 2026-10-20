class MonthlySummary {
  const MonthlySummary({
    required this.monthYear,
    required this.totals,
    required this.savingsGoals,
    required this.budgets,
    required this.topupBalance,
    required this.topupTransactions,
    required this.monthlyNetHistory,
    required this.categorySpending,
    required this.categoryIncome,
    required this.cumulativeBalance,
    required this.netSaved,
  });

  final String monthYear;
  final Map<String, double> totals;
  final List<dynamic> savingsGoals;
  final List<dynamic> budgets;
  final double topupBalance;
  final List<dynamic> topupTransactions;
  final List<Map<String, dynamic>> monthlyNetHistory;
  final List<Map<String, dynamic>> categorySpending;
  final List<Map<String, dynamic>> categoryIncome;
  final double cumulativeBalance;
  final double netSaved;
}
