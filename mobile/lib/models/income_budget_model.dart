double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class IncomeExpense {
  final String id;
  final String incomeId;
  final String title;
  final DateTime date;
  final double amount;
  final String? category;
  final String? notes;
  final DateTime? createdAt;

  IncomeExpense({
    required this.id,
    required this.incomeId,
    required this.title,
    required this.date,
    required this.amount,
    this.category,
    this.notes,
    this.createdAt,
  });

  factory IncomeExpense.fromJson(Map<String, dynamic> json) {
    return IncomeExpense(
      id: json['id']?.toString() ?? '',
      incomeId: json['income_id']?.toString() ?? '',
      title: json['title'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      amount: _toDouble(json['amount']),
      category: json['category'],
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'income_id': incomeId,
      'title': title,
      'date': date.toIso8601String().split('T').first,
      'amount': amount,
      'category': category,
      'notes': notes,
    };
  }
}

class IncomeSection {
  final String id;
  final String title;
  final DateTime date;
  final double amount;
  final String? notes;
  final DateTime? createdAt;
  final List<IncomeExpense> expenses;

  IncomeSection({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    this.notes,
    this.createdAt,
    this.expenses = const [],
  });

  factory IncomeSection.fromJson(Map<String, dynamic> json, [List<IncomeExpense>? expensesList]) {
    return IncomeSection(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      amount: _toDouble(json['amount']),
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      expenses: expensesList ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String().split('T').first,
      'amount': amount,
      'notes': notes,
    };
  }

  double get totalSpent => expenses.fold(0.0, (sum, exp) => sum + exp.amount);
  double get remainingBalance => amount - totalSpent;
}

