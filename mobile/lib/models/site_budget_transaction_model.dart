class SiteBudgetTransaction {
  final String id;
  final String siteId;
  final String siteName;
  final String transactionType; // 'add', 'reduce', 'set'
  final double amount;
  final double previousBudget;
  final double newBudget;
  final String? reason;
  final DateTime date;
  final String? createdBy;
  final DateTime createdAt;

  SiteBudgetTransaction({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.transactionType,
    required this.amount,
    required this.previousBudget,
    required this.newBudget,
    this.reason,
    required this.date,
    this.createdBy,
    required this.createdAt,
  });

  factory SiteBudgetTransaction.fromJson(Map<String, dynamic> json) {
    return SiteBudgetTransaction(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      siteName: json['site_name']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'add',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      previousBudget: (json['previous_budget'] as num?)?.toDouble() ?? 0.0,
      newBudget: (json['new_budget'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString(),
      date: json['date'] != null ? DateTime.parse(json['date'].toString()) : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'site_name': siteName,
      'transaction_type': transactionType,
      'amount': amount,
      'previous_budget': previousBudget,
      'new_budget': newBudget,
      'reason': reason,
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy,
    };
  }
}
