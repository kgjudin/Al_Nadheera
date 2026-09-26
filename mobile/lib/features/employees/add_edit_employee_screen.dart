import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/employee_model.dart';
import '../../models/site_model.dart';
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
  
  late TextEditingController _nameController;
  late TextEditingController _empIdController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _roleController;
  
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
    _roleController = TextEditingController(text: widget.employee?.role ?? '');
    
    _joiningDate = widget.employee?.joiningDate;
    _assignedSiteId = widget.employee?.assignedSiteId;
    if (widget.employee != null) {
      _status = widget.employee!.status;
    }
    
    _fetchSites();
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
    _roleController.dispose();
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
        'role': _roleController.text.trim(),
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

  Future<void> _showChangePasswordDialog() async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool obscureConfirm = true;
    String? errorMsg;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update password for ${widget.employee?.name ?? "staff member"}:',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
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
                  TextFormField(
                    controller: _roleController,
                    decoration: const InputDecoration(labelText: 'Role (e.g., Engineer, Labour)', border: OutlineInputBorder()),
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
                  const SizedBox(height: 32),
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
