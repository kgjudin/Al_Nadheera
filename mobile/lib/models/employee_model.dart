class Employee {
  final String id;
  final String? employeeId;
  final String name;
  final String? phone;
  final String? email;
  final String? role;
  final String? roleId;
  final Map<String, dynamic>? customPermissions;
  final DateTime? joiningDate;
  final String? assignedSiteId;
  final String? assignedSiteName;
  final String status;
  final String? profileImageUrl;
  final double? lastLatitude;
  final double? lastLongitude;
  final String? lastLocationAddress;
  final DateTime? lastLocationUpdatedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  Employee({
    required this.id,
    this.employeeId,
    required this.name,
    this.phone,
    this.email,
    this.role,
    this.roleId,
    this.customPermissions,
    this.joiningDate,
    this.assignedSiteId,
    this.assignedSiteName,
    required this.status,
    this.profileImageUrl,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAddress,
    this.lastLocationUpdatedAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      employeeId: json['employee_id'],
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      role: json['role'],
      roleId: json['role_id'],
      customPermissions: json['custom_permissions'] != null && json['custom_permissions'] is Map
          ? Map<String, dynamic>.from(json['custom_permissions'])
          : null,
      joiningDate: json['joining_date'] != null ? DateTime.tryParse(json['joining_date']) : null,
      assignedSiteId: json['assigned_site_id'],
      assignedSiteName: json['site'] != null ? json['site']['name'] : null,
      status: json['status'] ?? 'Active',
      profileImageUrl: json['profile_image_url'],
      lastLatitude: json['last_latitude'] != null ? (json['last_latitude'] as num).toDouble() : null,
      lastLongitude: json['last_longitude'] != null ? (json['last_longitude'] as num).toDouble() : null,
      lastLocationAddress: json['last_location_address'],
      lastLocationUpdatedAt: json['last_location_updated_at'] != null ? DateTime.tryParse(json['last_location_updated_at']) : null,
      isOnline: json['is_online'] == true,
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen']) : null,
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
      'role_id': roleId,
      'custom_permissions': customPermissions,
      'joining_date': joiningDate?.toIso8601String().split('T').first,
      'assigned_site_id': assignedSiteId,
      'status': status,
      'profile_image_url': profileImageUrl,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_location_address': lastLocationAddress,
      'last_location_updated_at': lastLocationUpdatedAt?.toIso8601String(),
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
