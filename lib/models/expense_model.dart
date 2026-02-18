class Expense {
  final int? id;
  final String item;
  final String category;
  final double cost;
  final String date; // ISO8601 format

  Expense({
    this.id,
    required this.item,
    required this.category,
    required this.cost,
    required this.date,
  });

  // Convert Expense object to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item': item,
      'category': category,
      'cost': cost,
      'date': date,
    };
  }

  // Create Expense object from Map (database query result)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      item: map['item'],
      category: map['category'],
      cost: map['cost'],
      date: map['date'],
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, item: $item, category: $category, cost: $cost, date: $date}';
  }
}
