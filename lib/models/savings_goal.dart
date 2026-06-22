class SavingsGoal {
  final int? id;
  final String title;
  final double targetAmount;
  final String createdAt; // YYYY-MM-DD
  
  // Aggregate field
  final double currentAmount; 

  SavingsGoal({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.createdAt,
    this.currentAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'target_amount': targetAmount,
      'created_at': createdAt,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as int?,
      title: map['title'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      currentAmount: map['current_amount'] != null ? (map['current_amount'] as num).toDouble() : 0.0,
    );
  }
}
