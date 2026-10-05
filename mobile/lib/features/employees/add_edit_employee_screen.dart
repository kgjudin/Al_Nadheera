import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../models/employee_model.dart';
import '../../models/role_model.dart';
import '../../models/site_model.dart';
import '../roles/employee_custom_permissions_screen.dart';
import 'package:intl/intl.dart';

class AddEditEmployeeScreen extends StatefulWidget {
  final Employee? employee;

  const AddEditEmployeeScreen({super.key, this.employee});

  @override
  State<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends State<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final PermissionService _permissionService = PermissionService.instance;
  
  late TextEditingController _nameController;
  late TextEditingController _empIdController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  List<AppRole> _availableRoles = [];
  String? _selectedRoleId;
  String _selectedRoleName = 'Employee';
  bool _isLoadingRoles = true;

  DateTime? _joiningDate;
  String _status = 'Active';
  String? _assignedSiteId;
  List<Site> _sites = [];
  bool _isLoading = false;
  bool _isLoadingSites = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee?.name ?? '');
    _empIdController = TextEditingController(text: widget.employee?.employeeId ?? '');
    _phoneController = TextEditingController(text: widget.employee?.phone ?? '');
    _emailController = TextEditingController(text: widget.employee?.email ?? '');
    
    _joiningDate = widget.employee?.joiningDate;
    _assignedSiteId = widget.employee?.assignedSiteId;
    if (widget.employee != null) {
      _status = widget.employee!.status;
      final empRole = widget.employee!.role;
      _selectedRoleName = (empRole != null && empRole.isNotEmpty) ? empRole : 'Employee';
    }
    
    _fetchSites();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final roles = await _permissionService.fetchAllRoles();
      if (mounted) {
        setState(() {
          _availableRoles = roles;
          final match = roles.firstWhere(
            (r) => r.name.toLowerCase() == _selectedRoleName.toLowerCase(),
            orElse: () => roles.firstWhere(
              (r) => r.name.toLowerCase() == 'employee',
              orElse: () => roles.isNotEmpty ? roles.first : AppRole(id: '', name: 'Employee'),
            ),
          );
          _selectedRoleId = match.id.isNotEmpty ? match.id : null;
          _selectedRoleName = match.name;
          _isLoadingRoles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoles = false);
      }
    }
  }

  Future<void> _fetchSites() async {
    try {
      final sites = await _apiService.getSites();
      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSites = false;
        });
      }
    }
  }

  List<DropdownMenuItem<String>> _buildSiteDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('None')),
    ];

    if (_assignedSiteId != null && !_sites.any((s) => s.id == _assignedSiteId)) {
      items.add(
        DropdownMenuItem<String>(
          value: _assignedSiteId,
          child: Text(widget.employee?.assignedSiteName ?? 'Assigned Site'),
        ),
      );
    }

    for (final s in _sites) {
      items.add(DropdownMenuItem<String>(value: s.id, child: Text(s.name)));
    }

    return items;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _empIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'employee_id': _empIdController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRoleName,
        'role_id': _selectedRoleId,
        'joining_date': _joiningDate?.toIso8601String(),
        'status': _status,
        'assigned_site_id': _assignedSiteId,
      };

      if (widget.employee == null) {
        await _apiService.createEmployee(data);
      } else {
        await _apiService.updateEmployee(widget.employee!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.employee == null ? 'Employee created successfully' : 'Employee updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _joiningDate) {
      setState(() {
        _joiningDate = picked;
      });
    }
  }

  void _showChangePasswordDialog() {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSubmitting = false;
    bool obscure = true;
    bool obscureConfirm = true;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change password for ${widget.employee!.name}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMsg!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final pwd = passwordCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();

                          if (pwd.length < 6) {
                            setDialogState(() {
                              errorMsg = 'Password must be at least 6 characters';
                            });
                            return;
                          }
                          if (pwd != confirm) {
                            setDialogState(() {
                              errorMsg = 'Passwords do not match';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _apiService.changeEmployeePassword(widget.employee!.id, pwd);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
        actions: [
          if (widget.employee != null)
            IconButton(
              icon: const Icon(Icons.lock_reset_rounded),
              tooltip: 'Change Password',
              onPressed: _showChangePasswordDialog,
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _empIdController,
                    decoration: const InputDecoration(labelText: 'Employee ID', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Role Selector Dropdown with System & Custom Roles
                  DropdownButtonFormField<String>(
                    value: _selectedRoleId,
                    decoration: InputDecoration(
                      labelText: 'Role & Access Level *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.shield_outlined),
                      suffixIcon: _isLoadingRoles
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    items: _availableRoles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(
                          '${r.name}${r.isSystem ? "" : " (Custom)"}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = _availableRoles.firstWhere((r) => r.id == val);
                        setState(() {
                          _selectedRoleId = val;
                          _selectedRoleName = matched.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    title: Text(_joiningDate == null ? 'Select Joining Date' : 'Joining Date: ${DateFormat('yyyy-MM-dd').format(_joiningDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade400, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 16),

                  Builder(
                    builder: (context) {
                      final siteItems = _buildSiteDropdownItems();
                      final isValidSite = siteItems.any((item) => item.value == _assignedSiteId);
                      return DropdownButtonFormField<String>(
                        value: isValidSite ? _assignedSiteId : null,
                        decoration: InputDecoration(
                          labelText: 'Assign to Site',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingSites
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        items: siteItems,
                        onChanged: (val) {
                          setState(() => _assignedSiteId = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final statusOptions = ['Active', 'Inactive', 'On Leave'];
                      if (!statusOptions.contains(_status)) {
                        statusOptions.add(_status);
                      }
                      return DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: statusOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _saveEmployee,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SAVE EMPLOYEE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  if (widget.employee != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmployeeCustomPermissionsScreen(employee: widget.employee!),
                          ),
                        ).then((_) => _fetchRoles());
                      },
                      icon: const Icon(Icons.security_rounded, color: Color(0xFF8E24AA)),
                      label: const Text('CUSTOMIZE MODULE & SITE PERMISSIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8E24AA))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF8E24AA)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('CHANGE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ),
    );
  }
}
