class TaskModel {
  final String id;
  final String siteId;
  final String title;
  final String? description;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String status;

  TaskModel({
    required this.id,
    required this.siteId,
    required this.title,
    this.description,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.startDate,
    this.dueDate,
    required this.status,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      assignedEmployeeId: json['assigned_employee_id']?.toString(),
      assignedEmployeeName: json['employee'] != null ? json['employee']['name'] : null,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      status: json['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'title': title,
      'description': description,
      'assigned_employee_id': assignedEmployeeId,
      'start_date': startDate?.toIso8601String().split('T').first,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'status': status,
    };
  }

  TaskModel copyWith({
    String? id,
    String? siteId,
    String? title,
    String? description,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
  }) {
    return TaskModel(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }
}
