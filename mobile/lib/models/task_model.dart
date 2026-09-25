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
      id: json['id'],
      siteId: json['site_id'],
      title: json['title'],
      description: json['description'],
      assignedEmployeeId: json['assigned_employee_id'],
      assignedEmployeeName: json['employee'] != null ? json['employee']['name'] : null,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      status: json['status'] ?? 'Pending',
    );
  }
}
