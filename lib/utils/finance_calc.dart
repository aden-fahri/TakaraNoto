import '../models/budget.dart';
import '../models/transaction.dart';

/// Number of days in a `YYYY-MM` month string.
int daysInMonth(String monthYear) {
  try {
    final parts = monthYear.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    // Last day of current month is the 0th day of next month
    return DateTime(year, month + 1, 0).day;
  } catch (_) {
    return 30;
  }
}

/// Monthly equivalent of a budget limit. Daily limits are multiplied by the
/// number of days in the month so progress can be tracked monthly.
double monthlyBudgetLimit(Budget budget, int days) {
  if (budget.budgetType == 'daily_limit') {
    return budget.limitAmount * days;
  }
  return budget.limitAmount;
}

/// Total income that counts towards statistics: excludes transfers and
/// savings withdrawals (categories flagged with `is_savings`).
double sumIncome(List<FinanceTransaction> txs) => txs
    .where((t) => !t.isTransfer && !t.categoryIsSavings && t.type == 'income')
    .fold(0.0, (sum, t) => sum + t.amount);

/// Total expense that counts towards statistics: excludes transfers and
/// savings deposits. Savings flows are reported separately as net saved.
double sumExpense(List<FinanceTransaction> txs) => txs
    .where((t) => !t.isTransfer && !t.categoryIsSavings && t.type == 'expense')
    .fold(0.0, (sum, t) => sum + t.amount);

/// Net cash flow (income - expense) for a list of transactions.
double netBalance(List<FinanceTransaction> txs) =>
    sumIncome(txs) - sumExpense(txs);

/// Budget usage ratio clamped to 0..1 (0 when no limit is set).
double budgetUsagePct(double spent, double limit) =>
    limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
