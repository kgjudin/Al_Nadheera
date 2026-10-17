class TaskSubModule {
  final String id;
  final String title;
  final String status; // 'Pending', 'Ongoing', 'Completed'
  final String? description;
  final String? updatedBy;
  final DateTime? updatedAt;

  TaskSubModule({
    required this.id,
    required this.title,
    this.status = 'Pending',
    this.description,
    this.updatedBy,
    this.updatedAt,
  });

  factory TaskSubModule.fromJson(Map<String, dynamic> json) {
    return TaskSubModule(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      description: json['description']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      if (description != null) 'description': description,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  TaskSubModule copyWith({
    String? id,
    String? title,
    String? status,
    String? description,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return TaskSubModule(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      description: description ?? this.description,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TaskModel {
  final String id;
  final String siteId;
  final String title;
  final String? description;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final String? siteName;
  final String? siteCode;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String status;
  final List<TaskSubModule> subModules;

  TaskModel({
    required this.id,
    required this.siteId,
    required this.title,
    this.description,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.siteName,
    this.siteCode,
    this.startDate,
    this.dueDate,
    required this.status,
    this.subModules = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    List<TaskSubModule> subs = [];
    final rawSub = json['sub_modules'];
    if (rawSub is List) {
      subs = rawSub.map((e) {
        if (e is Map<String, dynamic>) {
          return TaskSubModule.fromJson(e);
        } else if (e is Map) {
          return TaskSubModule.fromJson(Map<String, dynamic>.from(e));
        } else if (e is String && e.trim().isNotEmpty) {
          return TaskSubModule(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: e.trim(),
            status: 'Pending',
          );
        }
        return TaskSubModule(id: '', title: '');
      }).where((s) => s.title.isNotEmpty).toList();
    }

    return TaskModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      assignedEmployeeId: json['assigned_employee_id']?.toString(),
      assignedEmployeeName: json['employee'] != null ? json['employee']['name'] : null,
      siteName: json['site'] != null ? json['site']['name'] : null,
      siteCode: json['site'] != null ? json['site']['code'] : null,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      status: json['status'] ?? 'Pending',
      subModules: subs,
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
      'sub_modules': subModules.map((s) => s.toJson()).toList(),
    };
  }

  int get completedSubModulesCount =>
      subModules.where((s) => s.status.toLowerCase() == 'completed' || s.status.toLowerCase() == 'done').length;

  int get ongoingSubModulesCount =>
      subModules.where((s) => s.status.toLowerCase().contains('progress') || s.status.toLowerCase() == 'ongoing').length;

  int get pendingSubModulesCount =>
      subModules.where((s) => s.status.toLowerCase() == 'pending').length;

  double get subModulesProgress =>
      subModules.isEmpty ? 0.0 : completedSubModulesCount / subModules.length;

  TaskModel copyWith({
    String? id,
    String? siteId,
    String? title,
    String? description,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    String? siteName,
    String? siteCode,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
    List<TaskSubModule>? subModules,
  }) {
    return TaskModel(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      siteName: siteName ?? this.siteName,
      siteCode: siteCode ?? this.siteCode,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      subModules: subModules ?? this.subModules,
    );
  }
}
