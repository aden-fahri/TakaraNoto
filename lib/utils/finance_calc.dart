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
/// savings withdrawals (income linked to a savings goal).
double sumIncome(List<FinanceTransaction> txs) => txs
    .where((t) => !t.isTransfer && t.type == 'income' && t.savingsGoalId == null)
    .fold(0.0, (sum, t) => sum + t.amount);

/// Total expense that counts towards statistics: excludes transfers and
/// subtracts savings withdrawals (they return money to the main wallet).
double sumExpense(List<FinanceTransaction> txs) {
  return txs.where((t) => !t.isTransfer).fold(0.0, (sum, t) {
    if (t.type == 'expense') return sum + t.amount;
    if (t.type == 'income' && t.savingsGoalId != null) return sum - t.amount;
    return sum;
  });
}

/// Net cash flow (income - expense) for a list of transactions.
double netBalance(List<FinanceTransaction> txs) =>
    sumIncome(txs) - sumExpense(txs);

/// Budget usage ratio clamped to 0..1 (0 when no limit is set).
double budgetUsagePct(double spent, double limit) =>
    limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
