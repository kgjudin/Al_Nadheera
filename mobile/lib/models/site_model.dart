double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class Site {
  final String id;
  final String name;
  final String? code;
  final String? clientName;
  final String? location;
  final DateTime? startDate;
  final String status;
  final double assignedBudget;
  final double spent;
  final double receivedSummary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Site({
    required this.id,
    required this.name,
    this.code,
    this.clientName,
    this.location,
    this.startDate,
    required this.status,
    required this.assignedBudget,
    this.spent = 0.0,
    this.receivedSummary = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      code: json['code'],
      clientName: json['client_name'],
      location: json['location'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      status: json['status'] ?? 'Active',
      assignedBudget: _toDouble(json['assigned_budget']),
      spent: _toDouble(json['spent']),
      receivedSummary: _toDouble(json['received_summary']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'client_name': clientName,
      'location': location,
      'start_date': startDate?.toIso8601String().split('T').first,
      'status': status,
      'assigned_budget': assignedBudget,
      'spent': spent,
      'received_summary': receivedSummary,
    };
  }

  double get effectiveGiven => receivedSummary > 0 ? receivedSummary : assignedBudget;
  double get remainingBalance => effectiveGiven - spent;
}


