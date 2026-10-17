class Category {
  final int? id;
  final String name;
  final String icon; // Icon identifier (e.g. Ionicons names like 'fast_food')
  final String color; // Hex string (e.g. '#ff7f50')
  final String type; // 'income' or 'expense'

  /// Categories used internally by savings / transfer features.
  /// These must never be deleted because core flows depend on them.
  static const List<String> specialNames = [
    'Tabungan',
    'Tarik Tabungan',
    'Top Up',
    'Transfer Masuk',
  ];

  bool get isSpecial => specialNames.contains(name);

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      type: map['type'] as String,
    );
  }
}
