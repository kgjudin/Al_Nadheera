import 'package:flutter/material.dart';
import '../../models/role_model.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';

class EditRolePermissionsScreen extends StatefulWidget {
  final AppRole? role;
  final bool isNew;

  const EditRolePermissionsScreen({
    super.key,
    this.role,
    this.isNew = false,
  });

  @override
  State<EditRolePermissionsScreen> createState() => _EditRolePermissionsScreenState();
}

class _EditRolePermissionsScreenState extends State<EditRolePermissionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _permissionService = PermissionService.instance;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  final Map<String, ModulePermission> _permissions = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role?.name ?? '');
    _descriptionController = TextEditingController(text: widget.role?.description ?? '');

    // Initialize permissions for all modules
    for (final mod in AppModules.allModules) {
      if (widget.role != null && widget.role!.permissions.containsKey(mod)) {
        final existing = widget.role!.permissions[mod]!;
        _permissions[mod] = ModulePermission(
          moduleKey: mod,
          canView: existing.canView,
          canCreate: existing.canCreate,
          canEdit: existing.canEdit,
          canDelete: existing.canDelete,
        );
      } else {
        _permissions[mod] = ModulePermission(
          moduleKey: mod,
          canView: false,
          canCreate: false,
          canEdit: false,
          canDelete: false,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleAllPermissions(bool value) {
    setState(() {
      for (final mod in AppModules.allModules) {
        _permissions[mod] = ModulePermission(
          moduleKey: mod,
          canView: value,
          canCreate: value,
          canEdit: value,
          canDelete: value,
        );
      }
    });
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isSaving = true);

    try {
      if (widget.isNew) {
        await _permissionService.createRole(
          name: name,
          description: description,
          permissions: _permissions,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Custom role "$name" created successfully!')),
          );
          Navigator.pop(context, true);
        }
      } else if (widget.role != null) {
        await _permissionService.updateRole(
          roleId: widget.role!.id,
          name: name,
          description: description,
          permissions: _permissions,
          isSystem: widget.role!.isSystem,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Permissions for "$name" updated successfully!')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving role: $e'), backgroundColor: Colors.red),
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
    final isSystemRole = widget.role?.isSystem ?? false;
    final isSuperAdmin = widget.role?.name.toLowerCase() == 'super admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          widget.isNew ? 'Create Custom Role' : 'Edit Role Permissions',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          if (!isSuperAdmin)
            TextButton(
              onPressed: _isSaving ? null : _saveRole,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0B5ED7),
                      ),
                    ),
            ),
        ],
      ),
      body: isSuperAdmin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Super Admin has unrestricted permissions across all modules and sub-options by default.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Role Details Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROLE DETAILS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            readOnly: isSystemRole && !widget.isNew,
                            decoration: InputDecoration(
                              labelText: 'Role Name',
                              hintText: 'e.g. Site Engineer, Storekeeper, Supervisor',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: isSystemRole && !widget.isNew,
                              fillColor: isSystemRole && !widget.isNew ? Colors.grey[100] : null,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter role name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Describe responsibilities and level of access...',
                              prefixIcon: const Icon(Icons.description_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Grant All Access', style: TextStyle(fontSize: 12)),
                        onPressed: () => _toggleAllPermissions(true),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        label: const Text('Revoke All', style: TextStyle(fontSize: 12, color: Colors.red)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _toggleAllPermissions(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Main Application Modules
                  _buildSectionHeader(
                    title: 'MAIN APPLICATION MODULES',
                    subtitle: 'Top-level navigation and app features',
                    icon: Icons.apps_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...AppModules.topLevelModules.map((m) => _buildModuleCard(m)),

                  const SizedBox(height: 24),

                  // Section 2: Site Sub-Options
                  _buildSectionHeader(
                    title: 'SITE SUB-OPTIONS (INSIDE EACH SITE)',
                    subtitle: 'Detailed tabs and operations within project sites',
                    icon: Icons.foundation_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...AppModules.siteSubModules.map((m) => _buildModuleCard(m)),

                  const SizedBox(height: 32),

                  // Bottom Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B5ED7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveRole,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.isNew ? 'Create Custom Role' : 'Save Permissions',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0B5ED7), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                  color: Color(0xFF0A2540),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(String moduleKey) {
    final perm = _permissions[moduleKey] ?? ModulePermission(moduleKey: moduleKey);
    final label = AppModules.getLabel(moduleKey);
    final desc = AppModules.getDescription(moduleKey);
    final icon = AppModules.getIcon(moduleKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: perm.canView
              ? const Color(0xFF0B5ED7).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: perm.canView
                      ? const Color(0xFF0B5ED7).withValues(alpha: 0.1)
                      : Colors.grey[200],
                  child: Icon(
                    icon,
                    size: 18,
                    color: perm.canView ? const Color(0xFF0B5ED7) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                    ],
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
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSubActionToggle(
                    label: 'Create / Add',
                    value: perm.canCreate,
                    onChanged: (val) => setState(() => perm.canCreate = val),
                  ),
                  _buildSubActionToggle(
                    label: 'Edit / Update',
                    value: perm.canEdit,
                    onChanged: (val) => setState(() => perm.canEdit = val),
                  ),
                  _buildSubActionToggle(
                    label: 'Delete',
                    value: perm.canDelete,
                    onChanged: (val) => setState(() => perm.canDelete = val),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubActionToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: const Color(0xFF0B5ED7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: value ? const Color(0xFF0A2540) : Colors.grey[600],
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
