import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/budget.dart';
import '../services/database_helper.dart';

class FinanceProvider extends ChangeNotifier {
  List<FinanceTransaction> _transactions = [];
  List<Category> _categories = [];
  List<SavingsGoal> _savingsGoals = [];
  List<Budget> _budgets = [];
  String _currentMonth = '';
  Map<String, double> _monthlyTotals = {'income': 0.0, 'expense': 0.0};
  bool _isLoading = false;

  double _topupBalance = 0.0;
  List<FinanceTransaction> _topupTransactions = [];
  List<Map<String, dynamic>> _monthlyNetHistory = [];
  List<Map<String, dynamic>> _categorySpending = [];
  List<Map<String, dynamic>> _categoryIncome = [];
  double _cumulativeBalance = 0.0;
  double _netSaved = 0.0;

  // Getters
  List<FinanceTransaction> get transactions => _transactions;
  List<Category> get categories => _categories;
  List<SavingsGoal> get savingsGoals => _savingsGoals;
  List<Budget> get budgets => _budgets;
  String get currentMonth => _currentMonth;
  Map<String, double> get monthlyTotals => _monthlyTotals;
  bool get isLoading => _isLoading;
  double get cumulativeBalance => _cumulativeBalance;
  double get netSaved => _netSaved;

  double get topupBalance => _topupBalance;
  List<FinanceTransaction> get topupTransactions => _topupTransactions;
  List<Map<String, dynamic>> get monthlyNetHistory => _monthlyNetHistory;
  List<Map<String, dynamic>> get categorySpending => _categorySpending;
  List<Map<String, dynamic>> get categoryIncome => _categoryIncome;

  bool get hasBudgetAlert {
    for (final b in _budgets) {
      if (b.limitAmount > 0) {
        final spent = b.totalSpent ?? 0.0;
        if (spent / b.limitAmount > 0.85) {
          return true;
        }
      }
    }
    return false;
  }

  FinanceProvider() {
    final now = DateTime.now();
    _currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await refreshAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    try {
      _transactions = await DatabaseHelper.instance.getTransactions();
      _categories = await DatabaseHelper.instance.getCategories();
      _savingsGoals = await DatabaseHelper.instance.getSavingsGoals();
      _budgets = await DatabaseHelper.instance.getBudgets(_currentMonth);
      _topupBalance = await DatabaseHelper.instance.getTopupWalletBalance();
      _topupTransactions = await DatabaseHelper.instance.getTopupTransactions();
      _monthlyNetHistory = await DatabaseHelper.instance.getMonthlyNetBalanceHistory();
      await refreshMonthlyDetails();
    } catch (e) {
      debugPrint('Error refreshing provider data: $e');
    }
  }

  Future<void> refreshMonthlyDetails() async {
    try {
      _monthlyTotals = await DatabaseHelper.instance.getMonthlyTotals(_currentMonth);
      _savingsGoals = await DatabaseHelper.instance.getSavingsGoals();
      _budgets = await DatabaseHelper.instance.getBudgets(_currentMonth);
      _topupBalance = await DatabaseHelper.instance.getTopupWalletBalance();
      _topupTransactions = await DatabaseHelper.instance.getTopupTransactions();
      _monthlyNetHistory = await DatabaseHelper.instance.getMonthlyNetBalanceHistory();
      _categorySpending = await DatabaseHelper.instance.getCategorySpending(_currentMonth);
      _categoryIncome = await DatabaseHelper.instance.getCategoryIncome(_currentMonth);
      _cumulativeBalance = await DatabaseHelper.instance.getCumulativeBalanceUpTo(_currentMonth);
      _netSaved = await DatabaseHelper.instance.getNetSaved(_currentMonth);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing monthly details: $e');
    }
  }

  void changeMonth(String monthYear) {
    _currentMonth = monthYear;
    refreshMonthlyDetails();
  }

  // --- Transactions Operations ---

  Future<void> addTx({
    required int categoryId,
    required double amount,
    required String type,
    required String date,
    required String note,
    int? savingsGoalId,
    String walletType = 'main',
  }) async {
    final tx = FinanceTransaction(
      categoryId: categoryId,
      amount: amount,
      type: type,
      date: date,
      note: note,
      savingsGoalId: savingsGoalId,
      walletType: walletType,
    );
    await DatabaseHelper.instance.addTransaction(tx);
    await refreshAll();
  }

  Future<void> deleteTx(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await refreshAll();
  }

  /// Moves money between the main wallet and the e-wallet as a paired
  /// transfer. Transfers never count as income/expense in statistics.
  Future<void> makeTransfer({
    required bool toTopup,
    required double amount,
    required String date,
    required String note,
  }) async {
    await DatabaseHelper.instance.addTransfer(
      toTopup: toTopup,
      amount: amount,
      date: date,
      note: note,
    );
    await refreshAll();
  }

  Future<void> updateTx({
    required int id,
    required int categoryId,
    required double amount,
    required String type,
    required String date,
    required String note,
    int? savingsGoalId,
    String walletType = 'main',
  }) async {
    final tx = FinanceTransaction(
      id: id,
      categoryId: categoryId,
      amount: amount,
      type: type,
      date: date,
      note: note,
      savingsGoalId: savingsGoalId,
      walletType: walletType,
    );
    await DatabaseHelper.instance.updateTransaction(tx);
    await refreshAll();
  }

  // --- Savings Goals Operations ---

  Future<void> addSavingsGoal({
    required String title,
    required double targetAmount,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final goal = SavingsGoal(
      title: title,
      targetAmount: targetAmount,
      createdAt: dateStr,
    );
    await DatabaseHelper.instance.addSavingsGoal(goal);
    await refreshAll();
  }

  Future<void> deleteSavingsGoal(int id) async {
    await DatabaseHelper.instance.deleteSavingsGoal(id);
    await refreshAll();
  }

  Future<void> updateSavingsGoal({
    required int id,
    required String title,
    required double targetAmount,
    required String createdAt,
  }) async {
    final goal = SavingsGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      createdAt: createdAt,
    );
    await DatabaseHelper.instance.updateSavingsGoal(goal);
    await refreshAll();
  }

  Future<void> addSavingTransaction({
    required int goalId,
    required double amount,
    required String note,
    required String date,
  }) async {
    // Find special 'Tabungan' category or default expense
    final tabunganCat = _categories.firstWhere(
      (c) => c.name == 'Tabungan' && c.type == 'expense',
      orElse: () => _categories.firstWhere(
        (c) => c.type == 'expense',
        orElse: () => Category(id: 7, name: 'Tabungan', icon: 'trending_up', color: '#1abc9c', type: 'expense'),
      ),
    );

    await addTx(
      categoryId: tabunganCat.id!,
      amount: amount,
      type: 'expense',
      date: date,
      note: note,
      savingsGoalId: goalId,
    );
  }

  Future<void> withdrawSavingTransaction({
    required int goalId,
    required double amount,
    required String note,
    required String date,
  }) async {
    // Find or create 'Tarik Tabungan' category
    int categoryId;
    final existing = _categories.where((c) => c.name == 'Tarik Tabungan' && c.type == 'income');
    if (existing.isNotEmpty) {
      categoryId = existing.first.id!;
    } else {
      final newCat = Category(
        name: 'Tarik Tabungan',
        icon: 'download',
        color: '#f39c12',
        type: 'income',
      );
      categoryId = await DatabaseHelper.instance.addCategory(newCat);
      await refreshAll();
    }

    await addTx(
      categoryId: categoryId,
      amount: amount,
      type: 'income',
      date: date,
      note: note,
      savingsGoalId: goalId,
    );
  }

  // --- Budgets Operations ---

  Future<void> addOrUpdateBg({
    required int categoryId,
    required double limitAmount,
    required String monthYear,
    required String budgetType,
  }) async {
    final bg = Budget(
      categoryId: categoryId,
      limitAmount: limitAmount,
      monthYear: monthYear,
      budgetType: budgetType,
    );
    await DatabaseHelper.instance.addOrUpdateBudget(bg);
    await refreshAll();
  }

  Future<void> deleteBg(int id) async {
    await DatabaseHelper.instance.deleteBudget(id);
    await refreshAll();
  }

  /// Budget for the same category in the previous month (used to prefill the
  /// budget modal when the current month has no budget yet).
  Future<Budget?> getPreviousMonthBudget(int categoryId) async {
    final parts = _currentMonth.split('-');
    if (parts.length != 2) return null;
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) - 1;
    if (month == 0) {
      month = 12;
      year--;
    }
    final prevMonth = '$year-${month.toString().padLeft(2, '0')}';
    try {
      final budgets = await DatabaseHelper.instance.getBudgets(prevMonth);
      final matches = budgets.where((b) => b.categoryId == categoryId).toList();
      return matches.isNotEmpty ? matches.first : null;
    } catch (_) {
      return null;
    }
  }

  // --- Categories Operations ---

  Future<void> addCat({
    required String name,
    required String icon,
    required String color,
    required String type,
  }) async {
    final cat = Category(
      name: name,
      icon: icon,
      color: color,
      type: type,
    );
    await DatabaseHelper.instance.addCategory(cat);
    await refreshAll();
  }

  Future<void> deleteCat(int id) async {
    final match = _categories.where((c) => c.id == id);
    if (match.isNotEmpty && match.first.isSpecial) return;
    await DatabaseHelper.instance.deleteCategory(id);
    await refreshAll();
  }

  // --- Helper Methods ---

  Future<List<Map<String, dynamic>>> getCategorySpendingList() async {
    return await DatabaseHelper.instance.getCategorySpending(_currentMonth);
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }
}
