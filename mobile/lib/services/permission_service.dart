import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role_model.dart';
import '../core/constants/app_modules.dart';

class PermissionService extends ChangeNotifier {
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;
  factory PermissionService() => _instance;
  PermissionService._internal();

  final _supabase = Supabase.instance.client;

  String _currentRole = 'Employee';
  String? _currentRoleId;
  bool _isSuperAdmin = false;
  bool _isAdmin = false;
  bool _isManager = false;
  bool _isLoading = false;

  Map<String, ModulePermission> _permissions = {};

  String get currentRole => _currentRole;
  String? get currentRoleId => _currentRoleId;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get isAdmin => _isAdmin || _isSuperAdmin;
  bool get isManager => _isManager || _isAdmin || _isSuperAdmin;
  bool get isLoading => _isLoading;
  Map<String, ModulePermission> get permissions => _permissions;

  bool canView(String moduleKey) {
    if (_isSuperAdmin) return true;
    final p = _permissions[moduleKey];
    if (p != null) return p.canView;
    if (_isAdmin) return true;
    return false;
  }

  bool canCreate(String moduleKey) {
    if (_isSuperAdmin) return true;
    final p = _permissions[moduleKey];
    if (p != null) return p.canCreate;
    if (_isAdmin) return true;
    return false;
  }

  bool canEdit(String moduleKey) {
    if (_isSuperAdmin) return true;
    final p = _permissions[moduleKey];
    if (p != null) return p.canEdit;
    if (_isAdmin) return true;
    return false;
  }

  bool canDelete(String moduleKey) {
    if (_isSuperAdmin) return true;
    final p = _permissions[moduleKey];
    if (p != null) return p.canDelete;
    if (_isAdmin) return moduleKey != AppModules.roleManagement;
    return false;
  }

  /// Initialize or refresh user permissions from Supabase
  Future<void> loadUserPermissions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _resetToGuest();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch employee record for current user (check both id and email safely)
      Map<String, dynamic>? employeeRes;
      try {
        final email = user.email?.trim();
        if (email != null && email.isNotEmpty) {
          final res = await _supabase
              .from('employees')
              .select('id, role, role_id, custom_permissions')
              .or('id.eq.${user.id},email.ilike.$email')
              .maybeSingle();
          employeeRes = res;
        } else {
          final res = await _supabase
              .from('employees')
              .select('id, role, role_id, custom_permissions')
              .eq('id', user.id)
              .maybeSingle();
          employeeRes = res;
        }
      } catch (e) {
        debugPrint('Error fetching employee record in loadUserPermissions: $e');
      }

      String roleName = 'Employee';
      String? roleId;
      Map<String, dynamic>? customOverrides;

      if (employeeRes != null) {
        roleName = employeeRes['role']?.toString() ?? 'Employee';
        roleId = employeeRes['role_id']?.toString();
        if (employeeRes['custom_permissions'] != null && employeeRes['custom_permissions'] is Map) {
          customOverrides = Map<String, dynamic>.from(employeeRes['custom_permissions']);
        }
      } else {
        // Fallback to user metadata
        roleName = user.userMetadata?['role']?.toString() ?? 'Employee';
      }

      // Check for project owner accounts (Judin / Super Admin)
      final userEmailLower = user.email?.trim().toLowerCase() ?? '';
      final isOwner = userEmailLower == 'judin@gmail.com' ||
          userEmailLower == 'superadmin@alnadheera.com' ||
          user.userMetadata?['role']?.toString().trim().toLowerCase() == 'super admin';

      if (isOwner) {
        roleName = 'Super Admin';
        roleId = '21bb0756-c858-41c5-946e-abb69ed749e0';
        // Auto-heal employees table if accidentally demoted
        if (employeeRes != null && employeeRes['role']?.toString().toLowerCase() != 'super admin') {
          _supabase.from('employees').update({
            'role': 'Super Admin',
            'role_id': '21bb0756-c858-41c5-946e-abb69ed749e0',
          }).eq('id', employeeRes['id']).then((_) {}).catchError((_) {});
        }
      }

      _currentRole = roleName;
      _currentRoleId = roleId;

      final normalizedRole = roleName.trim().toLowerCase();
      _isSuperAdmin = isOwner || normalizedRole == 'super admin';
      _isAdmin = normalizedRole == 'admin' || _isSuperAdmin;
      _isManager = normalizedRole == 'manager' || _isAdmin;

      if (_isSuperAdmin) {
        // Full unrestricted permissions
        _permissions = {
          for (final m in AppModules.allModules)
            m: ModulePermission(
              moduleKey: m,
              canView: true,
              canCreate: true,
              canEdit: true,
              canDelete: true,
            ),
        };
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Fetch role permissions from role_permissions table
      List<dynamic> rolePermRows = [];
      if (roleId != null && roleId.isNotEmpty) {
        final res = await _supabase
            .from('role_permissions')
            .select('*')
            .eq('role_id', roleId);
        rolePermRows = res as List;
      } else {
        // Find role by name
        final roleMatch = await _supabase
            .from('roles')
            .select('id, role_permissions(*)')
            .ilike('name', roleName)
            .maybeSingle();

        if (roleMatch != null && roleMatch['role_permissions'] != null) {
          _currentRoleId = roleMatch['id']?.toString();
          rolePermRows = roleMatch['role_permissions'] as List;
        }
      }

      // Map base permissions
      final Map<String, ModulePermission> baseMap = {};
      for (final mod in AppModules.allModules) {
        final match = rolePermRows.firstWhere(
          (r) => r['module_key']?.toString() == mod,
          orElse: () => null,
        );

        if (match != null) {
          baseMap[mod] = ModulePermission.fromJson(match);
        } else {
          final isRestricted = mod.contains('budget') || mod == AppModules.roleManagement;
          final isStaffDefaultAllowed = mod == AppModules.sites ||
              mod == AppModules.chat ||
              mod == AppModules.products ||
              mod == AppModules.personal ||
              mod == AppModules.siteSummary ||
              mod == AppModules.siteTasks ||
              mod == AppModules.siteLabour ||
              mod == AppModules.siteMaterials ||
              mod == AppModules.siteChat;

          if (_isAdmin) {
            baseMap[mod] = ModulePermission(
              moduleKey: mod,
              canView: true,
              canCreate: true,
              canEdit: true,
              canDelete: mod != AppModules.roleManagement,
            );
          } else if (_isManager) {
            baseMap[mod] = ModulePermission(
              moduleKey: mod,
              canView: mod != AppModules.roleManagement,
              canCreate: !isRestricted,
              canEdit: !isRestricted,
              canDelete: false,
            );
          } else {
            // Default role (Employee / Staff)
            baseMap[mod] = ModulePermission(
              moduleKey: mod,
              canView: isStaffDefaultAllowed,
              canCreate: mod == AppModules.chat ||
                  mod == AppModules.personal ||
                  mod == AppModules.siteTasks ||
                  mod == AppModules.siteLabour ||
                  mod == AppModules.siteMaterials ||
                  mod == AppModules.siteChat,
              canEdit: mod == AppModules.chat ||
                  mod == AppModules.personal ||
                  mod == AppModules.siteTasks ||
                  mod == AppModules.siteChat,
              canDelete: false,
            );
          }
        }
      }

      // 3. Apply custom employee permission overrides if present
      if (customOverrides != null) {
        for (final entry in customOverrides.entries) {
          final mod = entry.key;
          if (entry.value is Map) {
            final val = Map<String, dynamic>.from(entry.value);
            final current = baseMap[mod] ?? ModulePermission(moduleKey: mod);
            baseMap[mod] = current.copyWith(
              canView: val['can_view'] == true || val['can_view'] == 1 || val['can_view']?.toString() == 'true',
              canCreate: val['can_create'] == true || val['can_create'] == 1 || val['can_create']?.toString() == 'true',
              canEdit: val['can_edit'] == true || val['can_edit'] == 1 || val['can_edit']?.toString() == 'true',
              canDelete: val['can_delete'] == true || val['can_delete'] == 1 || val['can_delete']?.toString() == 'true',
            );
          }
        }
      }

      _permissions = baseMap;
    } catch (e) {
      debugPrint('Error loading user permissions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetToGuest() {
    _currentRole = 'Guest';
    _currentRoleId = null;
    _isSuperAdmin = false;
    _isAdmin = false;
    _isManager = false;
    _permissions = {};
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch all system and custom roles with their permissions
  Future<List<AppRole>> fetchAllRoles() async {
    try {
      final res = await _supabase
          .from('roles')
          .select('*, permissions:role_permissions(*)')
          .order('is_system', ascending: false)
          .order('name', ascending: true);


      return (res as List).map((json) => AppRole.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching all roles: $e');
      rethrow;
    }
  }

  /// Create a new custom role with permissions
  Future<AppRole> createRole({
    required String name,
    required String description,
    required Map<String, ModulePermission> permissions,
  }) async {
    try {
      final trimmedName = name.trim();
      final insertRoleRes = await _supabase
          .from('roles')
          .insert({
            'name': trimmedName,
            'description': description.trim(),
            'is_system': false,
          })
          .select()
          .single();

      final newRoleId = insertRoleRes['id'].toString();

      final permRows = AppModules.allModules.map((m) {
        final p = permissions[m] ?? ModulePermission(moduleKey: m);
        return {
          'role_id': newRoleId,
          'module_key': m,
          'can_view': p.canView,
          'can_create': p.canCreate,
          'can_edit': p.canEdit,
          'can_delete': p.canDelete,
        };
      }).toList();

      final insertedPerms = await _supabase
          .from('role_permissions')
          .insert(permRows)
          .select();

      final fullData = Map<String, dynamic>.from(insertRoleRes);
      fullData['permissions'] = insertedPerms;
      return AppRole.fromJson(fullData);
    } catch (e) {
      debugPrint('Error creating role: $e');
      rethrow;
    }
  }

  /// Update an existing role's info and permission settings
  Future<void> updateRole({
    required String roleId,
    required String name,
    required String description,
    required Map<String, ModulePermission> permissions,
    required bool isSystem,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'description': description.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (!isSystem) {
        updateData['name'] = name.trim();
      }

      await _supabase
          .from('roles')
          .update(updateData)
          .eq('id', roleId);

      // Upsert permissions
      for (final m in AppModules.allModules) {
        final p = permissions[m] ?? ModulePermission(moduleKey: m);
        await _supabase.from('role_permissions').upsert({
          'role_id': roleId,
          'module_key': m,
          'can_view': p.canView,
          'can_create': p.canCreate,
          'can_edit': p.canEdit,
          'can_delete': p.canDelete,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'role_id,module_key');
      }

      // If updating current user's role, reload permissions
      if (_currentRoleId == roleId) {
        await loadUserPermissions();
      }
    } catch (e) {
      debugPrint('Error updating role: $e');
      rethrow;
    }
  }

  /// Delete a custom role
  Future<void> deleteRole(String roleId) async {
    try {
      // Find fallback Employee role ID
      final employeeRole = await _supabase
          .from('roles')
          .select('id')
          .eq('name', 'Employee')
          .maybeSingle();

      final fallbackId = employeeRole?['id'];

      // Reassign affected employees to Employee
      await _supabase
          .from('employees')
          .update({
            'role_id': fallbackId,
            'role': 'Employee',
          })
          .eq('role_id', roleId);

      // Delete the role (role_permissions cascades)
      await _supabase
          .from('roles')
          .delete()
          .eq('id', roleId);
    } catch (e) {
      debugPrint('Error deleting role: $e');
      rethrow;
    }
  }

  /// Save custom permission overrides for a specific employee
  Future<void> setEmployeeCustomPermissions({
    required String employeeId,
    required Map<String, ModulePermission>? customOverrides,
    String? role,
    String? roleId,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (customOverrides == null) {
        updates['custom_permissions'] = null;
      } else {
        final map = <String, dynamic>{};
        customOverrides.forEach((k, v) {
          map[k] = v.toJson();
        });
        updates['custom_permissions'] = map;
      }

      if (role != null) updates['role'] = role;
      if (roleId != null) updates['role_id'] = roleId;

      await _supabase
          .from('employees')
          .update(updates)
          .eq('id', employeeId);

      // If updating logged in user, refresh
      final currentAuthUser = _supabase.auth.currentUser;
      if (currentAuthUser != null && currentAuthUser.id == employeeId) {
        await loadUserPermissions();
      }
    } catch (e) {
      debugPrint('Error setting employee custom permissions: $e');
      rethrow;
    }
  }

  /// Get fresh employee details from employees table
  Future<Map<String, dynamic>?> getCurrentOrEmployeeDetails(String employeeId) async {
    try {
      final res = await _supabase
          .from('employees')
          .select('id, role, role_id, custom_permissions')
          .eq('id', employeeId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching employee details: $e');
      return null;
    }
  }
}
