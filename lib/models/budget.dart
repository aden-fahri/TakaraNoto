class Budget {
  final int? id;
  final int categoryId;
  final double limitAmount;
  final String monthYear; // YYYY-MM
  final String budgetType; // 'daily_limit' or 'goal'

  // Join and aggregation properties
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final double? totalSpent; // Dynamically calculated from database queries

  Budget({
    this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.monthYear,
    required this.budgetType,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.totalSpent,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'limit_amount': limitAmount,
      'month_year': monthYear,
      'budget_type': budgetType,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      limitAmount: (map['limit_amount'] as num).toDouble(),
      monthYear: map['month_year'] as String,
      budgetType: map['budget_type'] as String? ?? 'daily_limit',
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      categoryIcon: map['category_icon'] as String?,
      totalSpent: map['total_spent'] != null ? (map['total_spent'] as num).toDouble() : 0.0,
    );
  }
}
