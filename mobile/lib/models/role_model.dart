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

  factory ModulePermission.fromJson(Map json) {
    final m = Map<String, dynamic>.from(json);
    return ModulePermission(
      moduleKey: m['module_key']?.toString() ?? '',
      canView: m['can_view'] == true || m['can_view'] == 1 || m['can_view']?.toString() == 'true',
      canCreate: m['can_create'] == true || m['can_create'] == 1 || m['can_create']?.toString() == 'true',
      canEdit: m['can_edit'] == true || m['can_edit'] == 1 || m['can_edit']?.toString() == 'true',
      canDelete: m['can_delete'] == true || m['can_delete'] == 1 || m['can_delete']?.toString() == 'true',
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

  factory AppRole.fromJson(Map json) {
    final m = Map<String, dynamic>.from(json);
    final Map<String, ModulePermission> permMap = {};
    final permsList = m['permissions'] ?? m['role_permissions'];
    if (permsList != null && permsList is List) {
      for (final p in permsList) {
        if (p is Map) {
          final pMap = Map<String, dynamic>.from(p);
          final mod = pMap['module_key']?.toString() ?? '';
          if (mod.isNotEmpty) {
            permMap[mod] = ModulePermission.fromJson(pMap);
          }
        }
      }
    }
    return AppRole(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      isSystem: m['is_system'] == true || m['is_system'] == 1 || m['is_system']?.toString() == 'true',
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
