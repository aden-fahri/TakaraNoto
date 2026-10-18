import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/models/budget.dart';
import 'package:finflow_flutter/models/category.dart';
import 'package:finflow_flutter/models/transaction.dart';
import 'package:finflow_flutter/utils/finance_calc.dart';

FinanceTransaction tx({
  required double amount,
  required String type,
  bool isTransfer = false,
  bool categoryIsSavings = false,
  String walletType = 'main',
}) {
  return FinanceTransaction(
    categoryId: 1,
    amount: amount,
    type: type,
    date: '2026-10-01',
    note: '',
    isTransfer: isTransfer,
    categoryIsSavings: categoryIsSavings,
    walletType: walletType,
  );
}

void main() {
  group('daysInMonth', () {
    test('returns correct number of days', () {
      expect(daysInMonth('2026-10'), 31);
      expect(daysInMonth('2026-11'), 30);
      expect(daysInMonth('2026-02'), 28);
      expect(daysInMonth('2024-02'), 29);
    });

    test('falls back to 30 on invalid input', () {
      expect(daysInMonth('invalid'), 30);
      expect(daysInMonth(''), 30);
    });
  });

  group('monthlyBudgetLimit', () {
    test('goal budget is used as-is', () {
      final b = Budget(
        categoryId: 1,
        limitAmount: 500000,
        monthYear: '2026-10',
        budgetType: 'goal',
      );
      expect(monthlyBudgetLimit(b, 31), 500000);
    });

    test('daily limit is multiplied by days in month', () {
      final b = Budget(
        categoryId: 1,
        limitAmount: 20000,
        monthYear: '2026-10',
        budgetType: 'daily_limit',
      );
      expect(monthlyBudgetLimit(b, 31), 620000);
    });
  });

  group('aggregations', () {
    test('sumIncome excludes transfers and savings categories', () {
      final txs = [
        tx(amount: 1000000, type: 'income'),
        tx(amount: 500000, type: 'income', isTransfer: true),
        tx(amount: 200000, type: 'income', categoryIsSavings: true),
        tx(amount: 75000, type: 'expense'),
      ];
      expect(sumIncome(txs), 1000000);
    });

    test('sumExpense excludes transfers and savings categories', () {
      final txs = [
        tx(amount: 75000, type: 'expense'),
        tx(amount: 100000, type: 'expense', categoryIsSavings: true),
        tx(amount: 50000, type: 'income', categoryIsSavings: true),
        tx(amount: 500000, type: 'expense', isTransfer: true),
      ];
      expect(sumExpense(txs), 75000);
    });

    test('netBalance combines income and expense', () {
      final txs = [
        tx(amount: 1000000, type: 'income'),
        tx(amount: 300000, type: 'expense'),
        tx(amount: 400000, type: 'expense', isTransfer: true),
      ];
      expect(netBalance(txs), 700000);
    });

    test('budgetUsagePct handles zero limit and overflow', () {
      expect(budgetUsagePct(50000, 0), 0);
      expect(budgetUsagePct(250000, 500000), 0.5);
      expect(budgetUsagePct(900000, 500000), 1.0);
    });
  });

  group('FinanceTransaction.displayName', () {
    test('non transfer uses category name', () {
      final t = FinanceTransaction(
        categoryId: 1,
        amount: 1000,
        type: 'expense',
        date: '2026-10-01',
        note: '',
        categoryName: 'Makanan',
      );
      expect(t.displayName, 'Makanan');
    });

    test('main wallet transfer labels', () {
      expect(
        tx(amount: 1000, type: 'expense', isTransfer: true).displayName,
        'Transfer ke E-Wallet',
      );
      expect(
        tx(amount: 1000, type: 'income', isTransfer: true).displayName,
        'Tarik dari E-Wallet',
      );
    });

    test('topup wallet transfer labels', () {
      expect(
        tx(
          amount: 1000,
          type: 'income',
          isTransfer: true,
          walletType: 'topup',
        ).displayName,
        'Top Up Saldo',
      );
      expect(
        tx(
          amount: 1000,
          type: 'expense',
          isTransfer: true,
          walletType: 'topup',
        ).displayName,
        'Tarik ke Dompet Utama',
      );
    });
  });

  group('Category.isSpecial', () {
    test('flags internal categories', () {
      expect(
        Category(name: 'Tabungan', icon: 'x', color: '#fff', type: 'expense')
            .isSpecial,
        isTrue,
      );
      expect(
        Category(
          name: 'Transfer Masuk',
          icon: 'x',
          color: '#fff',
          type: 'income',
        ).isSpecial,
        isTrue,
      );
      expect(
        Category(name: 'Makanan', icon: 'x', color: '#fff', type: 'expense')
            .isSpecial,
        isFalse,
      );
    });
  });
}
