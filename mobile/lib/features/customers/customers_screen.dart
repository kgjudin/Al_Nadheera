import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/customer_model.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _supabase = Supabase.instance.client;
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('customers')
          .select('*')
          .order('name', ascending: true);

      final list = (res as List)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditCustomerDialog([Customer? customer]) async {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final vatCtrl = TextEditingController(text: customer?.vatNumber ?? '');
    final crCtrl = TextEditingController(text: customer?.crNumber ?? '');
    final notesCtrl = TextEditingController(text: customer?.notes ?? '');

    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    customer == null ? Icons.person_add_rounded : Icons.edit_rounded,
                    color: const Color(0xFF0A2540),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    customer == null ? 'Add Customer' : 'Edit Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer / Company Name *',
                            prefixIcon: Icon(Icons.business_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_rounded),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address / Location',
                            prefixIcon: Icon(Icons.location_on_rounded),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: vatCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'VAT / Tax No',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: crCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'CR Number',
                                  prefixIcon: Icon(Icons.badge_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Remarks / Notes',
                            prefixIcon: Icon(Icons.note_alt_rounded),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2540),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          final data = {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                            'vat_number': vatCtrl.text.trim().isEmpty ? null : vatCtrl.text.trim(),
                            'cr_number': crCtrl.text.trim().isEmpty ? null : crCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          };

                          try {
                            if (customer == null) {
                              await _supabase.from('customers').insert(data);
                            } else {
                              await _supabase.from('customers').update(data).eq('id', customer.id);
                            }
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            _loadCustomers();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(customer == null
                                    ? 'Customer added successfully'
                                    : 'Customer updated successfully'),
                                backgroundColor: const Color(0xFF137333),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error saving customer: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(customer == null ? 'Save Customer' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete "${customer.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('customers').delete().eq('id', customer.id);
      _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer "${customer.name}" deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete customer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.phone != null && c.phone!.contains(q)) ||
          (c.email != null && c.email!.toLowerCase().contains(q)) ||
          (c.address != null && c.address!.toLowerCase().contains(q)) ||
          (c.vatNumber != null && c.vatNumber!.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Customers Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer name, phone, or VAT...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Customer Count Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} Customer${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditCustomerDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A2540)),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEF2F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.groups_outlined, size: 48, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isEmpty ? 'No customers added yet' : 'No matching customers found',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add customers to select them quickly on invoices',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A2540),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showAddEditCustomerDialog(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add First Customer'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            return _buildCustomerCard(c);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditCustomerDialog(),
        tooltip: 'Add Customer',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0A2540).withValues(alpha: 0.1),
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      if (customer.address != null && customer.address!.isNotEmpty)
                        Text(
                          customer.address!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditCustomerDialog(customer);
                    } else if (val == 'delete') {
                      _deleteCustomer(customer);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Customer'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (customer.phone != null && customer.phone!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(customer.phone!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ],
                  ),
                if (customer.email != null && customer.email!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(customer.email!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ],
                  ),
                if (customer.vatNumber != null && customer.vatNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text('VAT: ${customer.vatNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ],
                  ),
                if (customer.crNumber != null && customer.crNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text('CR: ${customer.crNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
