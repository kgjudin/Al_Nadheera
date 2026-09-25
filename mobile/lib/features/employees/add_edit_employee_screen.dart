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
      setState(() {
        _sites = sites;
      });
    } catch (e) {
      // Handle error
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _assignedSiteId,
                    decoration: const InputDecoration(labelText: 'Assign to Site', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('None')),
                      ..._sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (val) {
                      setState(() => _assignedSiteId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: ['Active', 'Inactive', 'On Leave']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
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
                ],
              ),
            ),
        ),
    );
  }
}
