import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/site_model.dart';
import 'package:intl/intl.dart';

class AddEditSiteScreen extends StatefulWidget {
  final Site? site;

  const AddEditSiteScreen({super.key, this.site});

  @override
  State<AddEditSiteScreen> createState() => _AddEditSiteScreenState();
}

class _AddEditSiteScreenState extends State<AddEditSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _clientController;
  late TextEditingController _locationController;
  late TextEditingController _budgetController;
  
  DateTime? _startDate;
  String _status = 'Active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.site?.name ?? '');
    _codeController = TextEditingController(text: widget.site?.code ?? '');
    _clientController = TextEditingController(text: widget.site?.clientName ?? '');
    _locationController = TextEditingController(text: widget.site?.location ?? '');
    _budgetController = TextEditingController(text: widget.site != null ? widget.site!.assignedBudget.toString() : '');
    
    _startDate = widget.site?.startDate;
    if (widget.site != null) {
      _status = widget.site!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _clientController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final siteData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim(),
        'client_name': _clientController.text.trim(),
        'location': _locationController.text.trim(),
        'start_date': _startDate?.toIso8601String(),
        'status': _status,
        'assigned_budget': double.tryParse(_budgetController.text.trim()) ?? 0,
      };

      if (widget.site == null) {
        await _apiService.createSite(siteData);
      } else {
        await _apiService.updateSite(widget.site!.id, siteData);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.site == null ? 'Site created successfully' : 'Site updated successfully')),
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
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site == null ? 'Add Site' : 'Edit Site'),
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
                    decoration: const InputDecoration(labelText: 'Site Name *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Site Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'Site Code', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientController,
                    decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Site Location', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _budgetController,
                    decoration: const InputDecoration(labelText: 'Assigned Budget *', border: OutlineInputBorder(), prefixText: 'QAR '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Assigned Budget is required';
                      if (double.tryParse(value) == null) return 'Must be a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(_startDate == null ? 'Select Start Date' : 'Start Date: ${DateFormat('yyyy-MM-dd').format(_startDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade400, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: ['Active', 'Completed', 'Inactive']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveSite,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SAVE SITE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ),
    );
  }
}
