class FinanceTransaction {
  final int? id;
  final int categoryId;
  final double amount;
  final String type; // 'income' or 'expense'
  final String date; // YYYY-MM-DD
  final String note;
  final int? savingsGoalId; // Links to savings_goals(id)
  final String walletType; // 'main' or 'topup'
  final bool isTransfer; // True for wallet-to-wallet transfers (excluded from stats)
  final int? transferGroup; // Paired transfer rows share the same group id
  
  // Join properties
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final bool categoryIsSavings;

  FinanceTransaction({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    required this.note,
    this.savingsGoalId,
    this.walletType = 'main',
    this.isTransfer = false,
    this.transferGroup,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.categoryIsSavings = false,
  });

  /// Human friendly label, especially for internal transfer rows.
  String get displayName {
    if (!isTransfer) return categoryName ?? 'Tanpa Kategori';
    if (walletType == 'main') {
      return type == 'expense' ? 'Transfer ke E-Wallet' : 'Tarik dari E-Wallet';
    }
    return type == 'income' ? 'Top Up Saldo' : 'Tarik ke Dompet Utama';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'type': type,
      'date': date,
      'note': note,
      'savings_goal_id': savingsGoalId,
      'wallet_type': walletType,
      'is_transfer': isTransfer ? 1 : 0,
      'transfer_group': transferGroup,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      date: map['date'] as String,
      note: map['note'] as String? ?? '',
      savingsGoalId: map['savings_goal_id'] as int?,
      walletType: map['wallet_type'] as String? ?? 'main',
      isTransfer: (map['is_transfer'] as int? ?? 0) == 1,
      transferGroup: map['transfer_group'] as int?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
      categoryIsSavings: (map['category_is_savings'] as int? ?? 0) == 1,
    );
  }
}
