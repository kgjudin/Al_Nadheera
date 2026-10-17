import 'dart:convert';

double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class SiteSummary {
  final String id;
  final String siteId;
  final DateTime date;
  final double receivedAmount;
  final double cashExpenses;
  final double amount;
  final double balance;

  SiteSummary({
    required this.id,
    required this.siteId,
    required this.date,
    this.receivedAmount = 0,
    this.cashExpenses = 0,
    this.amount = 0,
    this.balance = 0,
  });

  factory SiteSummary.fromJson(Map<String, dynamic> json) {
    return SiteSummary(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      receivedAmount: _toDouble(json['received_amount']),
      cashExpenses: _toDouble(json['cash_expenses']),
      amount: _toDouble(json['amount']),
      balance: _toDouble(json['balance']),
    );
  }
}

class SiteBudget {
  final String id;
  final String siteId;
  final double incomeCame;
  final double incomeSpend;
  final double balance;

  SiteBudget({
    required this.id,
    required this.siteId,
    this.incomeCame = 0,
    this.incomeSpend = 0,
    this.balance = 0,
  });

  factory SiteBudget.fromJson(Map<String, dynamic> json) {
    return SiteBudget(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      incomeCame: _toDouble(json['income_came']),
      incomeSpend: _toDouble(json['income_spend']),
      balance: _toDouble(json['balance']),
    );
  }
}

class LabourCost {
  final String id;
  final String siteId;
  final DateTime date;
  final String labour;
  final double quantity;
  final double rate;
  final double amount;
  final double pending;

  LabourCost({
    required this.id,
    required this.siteId,
    required this.date,
    required this.labour,
    this.quantity = 0,
    this.rate = 0,
    this.amount = 0,
    this.pending = 0,
  });

  factory LabourCost.fromJson(Map<String, dynamic> json) {
    return LabourCost(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      labour: json['labour'] ?? '',
      quantity: _toDouble(json['quantity']),
      rate: _toDouble(json['rate']),
      amount: _toDouble(json['amount']),
      pending: _toDouble(json['pending']),
    );
  }
}

class MaterialAttachment {
  final String name;
  final String url;
  final String type; // 'image', 'pdf', 'excel', 'doc', 'other'
  final int? size;

  MaterialAttachment({
    required this.name,
    required this.url,
    required this.type,
    this.size,
  });

  factory MaterialAttachment.fromJson(Map<String, dynamic> json) {
    return MaterialAttachment(
      name: json['name']?.toString() ?? 'Attachment',
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'other',
      size: json['size'] is int ? json['size'] : int.tryParse(json['size']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'type': type,
    'size': size,
  };
}

class MaterialCost {
  final String id;
  final String siteId;
  final DateTime date;
  final String supplierName;
  final String? invoiceNumber;
  final double invoiceAmount;
  final double vatAmount;
  final String? remarks;
  final List<MaterialAttachment> attachments;

  double get totalAmount => invoiceAmount + vatAmount;

  MaterialCost({
    required this.id,
    required this.siteId,
    required this.date,
    required this.supplierName,
    this.invoiceNumber,
    this.invoiceAmount = 0,
    this.vatAmount = 0,
    this.remarks,
    this.attachments = const [],
  });

  factory MaterialCost.fromJson(Map<String, dynamic> json) {
    String? parsedRemarks = json['remarks'];
    List<MaterialAttachment> parsedAttachments = [];

    // Parse attachments list if directly provided
    if (json['attachments'] is List) {
      parsedAttachments = (json['attachments'] as List)
          .map((a) => MaterialAttachment.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    // If remarks contains encoded JSON with attachments and note text
    if (parsedRemarks != null && parsedRemarks.startsWith('{') && parsedRemarks.endsWith('}')) {
      try {
        final decoded = jsonDecode(parsedRemarks);
        if (decoded is Map) {
          if (decoded['text'] != null || decoded['remarks'] != null) {
            parsedRemarks = decoded['text']?.toString() ?? decoded['remarks']?.toString();
          }
          if (parsedAttachments.isEmpty && decoded['attachments'] is List) {
            parsedAttachments = (decoded['attachments'] as List)
                .map((a) => MaterialAttachment.fromJson(Map<String, dynamic>.from(a)))
                .toList();
          }
        }
      } catch (_) {}
    }

    return MaterialCost(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      supplierName: json['supplier_name'] ?? '',
      invoiceNumber: json['invoice_number'],
      invoiceAmount: _toDouble(json['invoice_amount']),
      vatAmount: _toDouble(json['vat_amount']),
      remarks: parsedRemarks,
      attachments: parsedAttachments,
    );
  }
}

class SubcontractorCost {
  final String id;
  final String siteId;
  final DateTime date;
  final String supplierName;
  final String? invoiceNumber;
  final double invoiceAmount;
  final double vatAmount;
  final String? remark;

  double get totalAmount => invoiceAmount + vatAmount;

  SubcontractorCost({
    required this.id,
    required this.siteId,
    required this.date,
    required this.supplierName,
    this.invoiceNumber,
    this.invoiceAmount = 0,
    this.vatAmount = 0,
    this.remark,
  });

  factory SubcontractorCost.fromJson(Map<String, dynamic> json) {
    return SubcontractorCost(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      supplierName: json['supplier_name'] ?? '',
      invoiceNumber: json['invoice_number'],
      invoiceAmount: _toDouble(json['invoice_amount']),
      vatAmount: _toDouble(json['vat_amount']),
      remark: json['remark'],
    );
  }
}

class AdditionalExpense {
  final String id;
  final String siteId;
  final DateTime date;
  final String expenseTitle;
  final double amount;
  final String? remarks;

  AdditionalExpense({
    required this.id,
    required this.siteId,
    required this.date,
    required this.expenseTitle,
    this.amount = 0,
    this.remarks,
  });

  factory AdditionalExpense.fromJson(Map<String, dynamic> json) {
    return AdditionalExpense(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      expenseTitle: json['expense_title'] ?? '',
      amount: _toDouble(json['amount']),
      remarks: json['remarks'],
    );
  }
}

