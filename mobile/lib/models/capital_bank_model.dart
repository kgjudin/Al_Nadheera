double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class CapitalBank {
  final String id;
  final String bankName;
  final String? accountNumber;
  final double balance;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CapitalBank({
    required this.id,
    required this.bankName,
    this.accountNumber,
    required this.balance,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory CapitalBank.fromJson(Map<String, dynamic> json) {
    return CapitalBank(
      id: json['id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString(),
      balance: _toDouble(json['balance']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'balance': balance,
      'notes': notes,
    };
  }

  CapitalBank copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    double? balance,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CapitalBank(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CapitalBankTransaction {
  final String id;
  final String bankId;
  final String bankName;
  final String transactionType; // 'deposit', 'withdrawal', 'site_allocation', 'company_allocation'
  final double amount;
  final double balanceAfter;
  final String? referenceTitle;
  final String? siteId;
  final String? incomeSectionId;
  final String? notes;
  final DateTime date;
  final String? createdBy;
  final DateTime? createdAt;

  CapitalBankTransaction({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    this.referenceTitle,
    this.siteId,
    this.incomeSectionId,
    this.notes,
    required this.date,
    this.createdBy,
    this.createdAt,
  });

  factory CapitalBankTransaction.fromJson(Map<String, dynamic> json) {
    return CapitalBankTransaction(
      id: json['id']?.toString() ?? '',
      bankId: json['bank_id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'deposit',
      amount: _toDouble(json['amount']),
      balanceAfter: _toDouble(json['balance_after']),
      referenceTitle: json['reference_title']?.toString(),
      siteId: json['site_id']?.toString(),
      incomeSectionId: json['income_section_id']?.toString(),
      notes: json['notes']?.toString(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_id': bankId,
      'bank_name': bankName,
      'transaction_type': transactionType,
      'amount': amount,
      'balance_after': balanceAfter,
      'reference_title': referenceTitle,
      'site_id': siteId,
      'income_section_id': incomeSectionId,
      'notes': notes,
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy,
    };
  }

  bool get isCredit => transactionType == 'deposit' || transactionType == 'company_return';
}
