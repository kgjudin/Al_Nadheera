class ModulePermission {
  final String moduleKey;
  bool canView;
  bool canCreate;
  bool canEdit;
  bool canDelete;

  ModulePermission({
    required this.moduleKey,
    this.canView = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory ModulePermission.fromJson(Map<String, dynamic> json) {
    return ModulePermission(
      moduleKey: json['module_key']?.toString() ?? '',
      canView: json['can_view'] == true,
      canCreate: json['can_create'] == true,
      canEdit: json['can_edit'] == true,
      canDelete: json['can_delete'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module_key': moduleKey,
      'can_view': canView,
      'can_create': canCreate,
      'can_edit': canEdit,
      'can_delete': canDelete,
    };
  }

  ModulePermission copyWith({
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
  }) {
    return ModulePermission(
      moduleKey: moduleKey,
      canView: canView ?? this.canView,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}

class AppRole {
  final String id;
  final String name;
  final String description;
  final bool isSystem;
  final Map<String, ModulePermission> permissions;

  AppRole({
    required this.id,
    required this.name,
    this.description = '',
    this.isSystem = false,
    this.permissions = const {},
  });

  factory AppRole.fromJson(Map<String, dynamic> json) {
    final Map<String, ModulePermission> permMap = {};
    if (json['permissions'] != null && json['permissions'] is List) {
      for (final p in (json['permissions'] as List)) {
        if (p is Map<String, dynamic>) {
          final mod = p['module_key']?.toString() ?? '';
          if (mod.isNotEmpty) {
            permMap[mod] = ModulePermission.fromJson(p);
          }
        }
      }
    }
    return AppRole(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isSystem: json['is_system'] == true,
      permissions: permMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_system': isSystem,
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}
