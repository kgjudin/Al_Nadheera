import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../models/role_model.dart';
import '../../core/constants/app_modules.dart';
import 'edit_role_permissions_screen.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final _permissionService = PermissionService.instance;
  List<AppRole> _roles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roles = await _permissionService.fetchAllRoles();
      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRole(AppRole role) async {
    if (role.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System roles cannot be deleted.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
          'Are you sure you want to delete the role "${role.name}"?\n'
          'Employees assigned to this role will be reassigned to the default "Employee" role.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _permissionService.deleteRole(role.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role "${role.name}" deleted successfully.')),
          );
        }
        _loadRoles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete role: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openCreateRoleScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditRolePermissionsScreen(isNew: true),
      ),
    );

    if (result == true) {
      _loadRoles();
    }
  }

  void _openEditRoleScreen(AppRole role) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRolePermissionsScreen(role: role, isNew: false),
      ),
    );

    if (result == true) {
      _loadRoles();
    }
  }

  int _countAllowedModules(AppRole role) {
    if (role.name.toLowerCase() == 'super admin') {
      return AppModules.allModules.length;
    }
    return role.permissions.values.where((p) => p.canView).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'Roles & Access Control',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadRoles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRoles,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A2540), Color(0xFF0B5ED7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B5ED7).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.security_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Access Levels & Permissions',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'Super Admin • Admin • Manager • Employee • Custom Roles',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Customize module permissions and sub-option tabs inside project sites (Summary, Tasks, Labour, Materials, Subcontractors, Budget, etc.).',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CONFIGURED ROLES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          '${_roles.length} Roles Total',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Role Cards
                    ..._roles.map((role) {
                      final isSuperAdmin = role.name.toLowerCase() == 'super admin';
                      final allowedCount = _countAllowedModules(role);
                      final totalCount = AppModules.allModules.length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: InkWell(
                          onTap: isSuperAdmin ? null : () => _openEditRoleScreen(role),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _getRoleColor(role.name).withValues(alpha: 0.15),
                                      child: Icon(
                                        _getRoleIcon(role.name),
                                        color: _getRoleColor(role.name),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  role.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF0A2540),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: role.isSystem
                                                      ? const Color(0xFFE8F0FE)
                                                      : const Color(0xFFE6F4EA),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  role.isSystem ? 'SYSTEM' : 'CUSTOM',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: role.isSystem
                                                        ? const Color(0xFF1967D2)
                                                        : const Color(0xFF137333),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            role.description.isNotEmpty
                                                ? role.description
                                                : 'No description provided',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!role.isSystem)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: 'Delete Role',
                                        onPressed: () => _deleteRole(role),
                                      ),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 16,
                                      color: isSuperAdmin ? Colors.green : const Color(0xFF0B5ED7),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isSuperAdmin
                                          ? 'Full System Access (All Modules & Sub-Options)'
                                          : 'Access to $allowedCount of $totalCount modules & sub-options',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSuperAdmin ? const Color(0xFF137333) : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 60),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRoleScreen,
        backgroundColor: const Color(0xFF0B5ED7),
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: const Text(
          'Create Custom Role',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _getRoleColor(String roleName) {
    final lower = roleName.toLowerCase();
    if (lower == 'super admin') return const Color(0xFFD9381E);
    if (lower == 'admin') return const Color(0xFF0B5ED7);
    if (lower == 'manager') return const Color(0xFF0F9D58);
    if (lower == 'employee') return const Color(0xFF5F6368);
    return const Color(0xFF8E24AA); // Custom roles
  }

  IconData _getRoleIcon(String roleName) {
    final lower = roleName.toLowerCase();
    if (lower == 'super admin') return Icons.shield_rounded;
    if (lower == 'admin') return Icons.admin_panel_settings_rounded;
    if (lower == 'manager') return Icons.manage_accounts_rounded;
    if (lower == 'employee') return Icons.person_rounded;
    return Icons.badge_rounded; // Custom role icon
  }
}
