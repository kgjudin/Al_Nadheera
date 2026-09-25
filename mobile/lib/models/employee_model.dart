class Employee {
  final String id;
  final String? employeeId;
  final String name;
  final String? phone;
  final String? email;
  final String? role;
  final DateTime? joiningDate;
  final String? assignedSiteId;
  final String? assignedSiteName;
  final String status;
  final String? profileImageUrl;

  Employee({
    required this.id,
    this.employeeId,
    required this.name,
    this.phone,
    this.email,
    this.role,
    this.joiningDate,
    this.assignedSiteId,
    this.assignedSiteName,
    required this.status,
    this.profileImageUrl,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      employeeId: json['employee_id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      role: json['role'],
      joiningDate: json['joining_date'] != null ? DateTime.parse(json['joining_date']) : null,
      assignedSiteId: json['assigned_site_id'],
      assignedSiteName: json['site'] != null ? json['site']['name'] : null,
      status: json['status'] ?? 'Active',
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'joining_date': joiningDate?.toIso8601String().split('T').first,
      'assigned_site_id': assignedSiteId,
      'status': status,
      'profile_image_url': profileImageUrl,
    };
  }
}
