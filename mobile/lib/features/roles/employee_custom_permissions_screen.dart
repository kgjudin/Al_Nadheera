import 'package:flutter/material.dart';
import '../../models/employee_model.dart';
import '../../models/role_model.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';

class EmployeeCustomPermissionsScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeCustomPermissionsScreen({super.key, required this.employee});

  @override
  State<EmployeeCustomPermissionsScreen> createState() => _EmployeeCustomPermissionsScreenState();
}

class _EmployeeCustomPermissionsScreenState extends State<EmployeeCustomPermissionsScreen> {
  final _permissionService = PermissionService.instance;
  List<AppRole> _roles = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedRoleId;
  String _selectedRoleName = 'Employee';

  bool _hasCustomOverrides = false;
  final Map<String, ModulePermission> _customPermissions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final roles = await _permissionService.fetchAllRoles();
      if (!mounted) return;

      setState(() {
        _roles = roles;
        final empRole = widget.employee.role;
        _selectedRoleName = (empRole != null && empRole.isNotEmpty) ? empRole : 'Employee';

        final match = roles.firstWhere(
          (r) => r.name.toLowerCase() == _selectedRoleName.toLowerCase(),
          orElse: () => roles.firstWhere(
            (r) => r.name.toLowerCase() == 'employee',
            orElse: () => roles.first,
          ),
        );
        _selectedRoleId = match.id;
        _selectedRoleName = match.name;

        // Initialize permissions from selected role
        _syncPermissionsWithRole(match);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading roles: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _syncPermissionsWithRole(AppRole role) {
    _customPermissions.clear();
    for (final mod in AppModules.allModules) {
      final rolePerm = role.permissions[mod];
      _customPermissions[mod] = ModulePermission(
        moduleKey: mod,
        canView: rolePerm?.canView ?? false,
        canCreate: rolePerm?.canCreate ?? false,
        canEdit: rolePerm?.canEdit ?? false,
        canDelete: rolePerm?.canDelete ?? false,
      );
    }
  }

  void _onRoleChanged(String? newRoleId) {
    if (newRoleId == null) return;
    final role = _roles.firstWhere((r) => r.id == newRoleId);
    setState(() {
      _selectedRoleId = role.id;
      _selectedRoleName = role.name;
      if (!_hasCustomOverrides) {
        _syncPermissionsWithRole(role);
      }
    });
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      await _permissionService.setEmployeeCustomPermissions(
        employeeId: widget.employee.id,
        role: _selectedRoleName,
        roleId: _selectedRoleId,
        customOverrides: _hasCustomOverrides ? _customPermissions : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access permissions for "${widget.employee.name}" updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update permissions: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          'Permissions: ${widget.employee.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePermissions,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B5ED7)),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Employee Info Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                            child: Text(
                              widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : 'E',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0B5ED7)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.employee.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.employee.email ?? widget.employee.phone ?? 'Staff Member',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Assigned Role Selector
                      const Text(
                        'ASSIGNED ROLE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRoleId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Icon(Icons.shield_outlined),
                        ),
                        items: _roles.map((r) {
                          return DropdownMenuItem<String>(
                            value: r.id,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  r.isSystem ? ' (System)' : ' (Custom)',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onRoleChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Custom Override Toggle Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Individual Permission Overrides',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Enable this to fine-tune modules or sub-options specifically for this employee without altering their base role.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _hasCustomOverrides,
                    activeColor: const Color(0xFF0B5ED7),
                    onChanged: (val) {
                      setState(() {
                        _hasCustomOverrides = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Permission Matrix
                if (_hasCustomOverrides) ...[
                  const Text(
                    'MAIN MODULE ACCESS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  ...AppModules.topLevelModules.map((m) => _buildModuleCard(m)),

                  const SizedBox(height: 20),
                  const Text(
                    'SITE SUB-OPTIONS (INSIDE EACH SITE)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  ...AppModules.siteSubModules.map((m) => _buildModuleCard(m)),

                  const SizedBox(height: 30),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF0B5ED7)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This employee currently inherits all permissions from the "$_selectedRoleName" role. Toggle "Individual Permission Overrides" above if you need employee-specific adjustments.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0A2540)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 50),
              ],
            ),
    );
  }

  Widget _buildModuleCard(String moduleKey) {
    final perm = _customPermissions[moduleKey] ?? ModulePermission(moduleKey: moduleKey);
    final label = AppModules.getLabel(moduleKey);
    final icon = AppModules.getIcon(moduleKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: perm.canView
              ? const Color(0xFF0B5ED7).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: perm.canView ? const Color(0xFF0B5ED7) : Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Switch(
                  value: perm.canView,
                  activeColor: const Color(0xFF0B5ED7),
                  onChanged: (val) {
                    setState(() {
                      perm.canView = val;
                      if (!val) {
                        perm.canCreate = false;
                        perm.canEdit = false;
                        perm.canDelete = false;
                      }
                    });
                  },
                ),
              ],
            ),
            if (perm.canView) ...[
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSubCheck(
                    label: 'Create',
                    value: perm.canCreate,
                    onChanged: (v) => setState(() => perm.canCreate = v),
                  ),
                  _buildSubCheck(
                    label: 'Edit',
                    value: perm.canEdit,
                    onChanged: (v) => setState(() => perm.canEdit = v),
                  ),
                  _buildSubCheck(
                    label: 'Delete',
                    value: perm.canDelete,
                    onChanged: (v) => setState(() => perm.canDelete = v),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubCheck({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: const Color(0xFF0B5ED7),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
