class FinanceTransaction {
  final int? id;
  final int categoryId;
  final double amount;
  final String type; // 'income' or 'expense'
  final String date; // YYYY-MM-DD
  final String note;
  final int? savingsGoalId; // Links to savings_goals(id)
  final String walletType; // 'main' or 'topup'
  
  // Join properties
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  FinanceTransaction({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    required this.note,
    this.savingsGoalId,
    this.walletType = 'main',
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

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
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
    );
  }
}
