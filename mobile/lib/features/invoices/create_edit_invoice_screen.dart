import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../models/site_model.dart';
import '../../services/api_service.dart';

class CreateEditInvoiceScreen extends StatefulWidget {
  final Invoice? invoiceToEdit;
  final String? initialSiteId;

  const CreateEditInvoiceScreen({
    super.key,
    this.invoiceToEdit,
    this.initialSiteId,
  });

  @override
  State<CreateEditInvoiceScreen> createState() => _CreateEditInvoiceScreenState();
}

class _CreateEditInvoiceScreenState extends State<CreateEditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _apiService = ApiService();
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

  // Form Controllers
  late TextEditingController _invoiceNumCtrl;
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerPhoneCtrl;
  late TextEditingController _customerAddressCtrl;
  late TextEditingController _customerVatCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _vatRateCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _paymentTermsCtrl;

  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String _status = 'Pending'; // 'Pending' or 'Paid'
  String _discountType = 'amount'; // 'amount' or 'percentage'

  List<Customer> _availableCustomers = [];
  List<Site> _availableSites = [];
  Customer? _selectedCustomer;
  Site? _selectedSite;

  bool _isLoadingData = true;
  bool _isSaving = false;

  // Dynamic Line Items
  final List<_ItemInputRow> _itemRows = [];

  @override
  void initState() {
    super.initState();
    final edit = widget.invoiceToEdit;

    _invoiceNumCtrl = TextEditingController(
      text: edit?.invoiceNumber ?? _generateDefaultInvoiceNumber(),
    );
    _customerNameCtrl = TextEditingController(text: edit?.customerName ?? '');
    _customerPhoneCtrl = TextEditingController(text: edit?.customerPhone ?? '');
    _customerAddressCtrl = TextEditingController(text: edit?.customerAddress ?? '');
    _customerVatCtrl = TextEditingController(text: edit?.customerVatNumber ?? '');
    _descriptionCtrl = TextEditingController(text: edit?.description ?? '');
    _discountCtrl = TextEditingController(
      text: edit != null && edit.discount > 0 ? edit.discount.toString() : '0',
    );
    _vatRateCtrl = TextEditingController(
      text: edit != null && edit.vatRate > 0 ? edit.vatRate.toString() : '0',
    );
    _notesCtrl = TextEditingController(
      text: edit?.notes ?? 'Payment is due within 14 days of invoice date. Thank you for your business.',
    );
    _paymentTermsCtrl = TextEditingController(
      text: edit?.paymentTerms ?? 'Direct Bank Transfer / Cheque',
    );

    if (edit != null) {
      _invoiceDate = edit.date;
      _dueDate = edit.dueDate;
      _status = edit.status;
      _discountType = edit.discountType;

      if (edit.items.isNotEmpty) {
        for (final item in edit.items) {
          _itemRows.add(_ItemInputRow(
            descriptionCtrl: TextEditingController(text: item.itemDescription),
            qtyCtrl: TextEditingController(text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString()),
            priceCtrl: TextEditingController(text: item.unitPrice.toString()),
          ));
        }
      }
    }

    if (_itemRows.isEmpty) {
      // Default initial row
      _itemRows.add(_ItemInputRow(
        descriptionCtrl: TextEditingController(text: 'General Contracting Services'),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(text: '0'),
      ));
    }

    _loadInitialData();
  }

  String _generateDefaultInvoiceNumber() {
    final now = DateTime.now();
    final randomSuffix = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'INV-${DateFormat('yyMM').format(now)}-$randomSuffix';
  }

  Future<void> _loadInitialData() async {
    try {
      final customersRes = await _supabase.from('customers').select('*').order('name');
      final customersList = (customersRes as List)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();

      List<Site> sitesList = [];
      try {
        sitesList = await _apiService.getSites();
      } catch (_) {
        final rawSites = await _supabase.from('sites').select('*').order('name');
        sitesList = (rawSites as List).map((s) => Site.fromJson(s as Map<String, dynamic>)).toList();
      }

      if (mounted) {
        setState(() {
          _availableCustomers = customersList;
          _availableSites = sitesList;

          if (widget.invoiceToEdit?.customerId != null) {
            _selectedCustomer = customersList.firstWhere(
              (c) => c.id == widget.invoiceToEdit!.customerId,
              orElse: () => Customer(id: '', name: widget.invoiceToEdit!.customerName, createdAt: DateTime.now()),
            );
          }

          if (widget.invoiceToEdit?.siteId != null || widget.initialSiteId != null) {
            final targetSiteId = widget.invoiceToEdit?.siteId ?? widget.initialSiteId;
            final match = sitesList.where((s) => s.id == targetSiteId).toList();
            if (match.isNotEmpty) {
              _selectedSite = match.first;
            }
          }

          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _invoiceNumCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAddressCtrl.dispose();
    _customerVatCtrl.dispose();
    _descriptionCtrl.dispose();
    _discountCtrl.dispose();
    _vatRateCtrl.dispose();
    _notesCtrl.dispose();
    _paymentTermsCtrl.dispose();
    for (final row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    double total = 0.0;
    for (final row in _itemRows) {
      final qty = double.tryParse(row.qtyCtrl.text.trim()) ?? 0.0;
      final price = double.tryParse(row.priceCtrl.text.trim()) ?? 0.0;
      total += qty * price;
    }
    return total;
  }

  double get _discountAmount {
    final discountVal = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    if (discountVal <= 0) return 0.0;
    if (_discountType == 'percentage') {
      return (_subtotal * discountVal) / 100.0;
    }
    return discountVal;
  }

  double get _vatAmount {
    final vatRate = double.tryParse(_vatRateCtrl.text.trim()) ?? 0.0;
    if (vatRate <= 0) return 0.0;
    final taxable = (_subtotal - _discountAmount).clamp(0.0, double.infinity);
    return (taxable * vatRate) / 100.0;
  }

  double get _grandTotal {
    final base = (_subtotal - _discountAmount).clamp(0.0, double.infinity);
    return base + _vatAmount;
  }

  void _onCustomerSelected(Customer? customer) {
    if (customer == null) return;
    setState(() {
      _selectedCustomer = customer;
      _customerNameCtrl.text = customer.name;
      if (customer.phone != null) _customerPhoneCtrl.text = customer.phone!;
      if (customer.address != null) _customerAddressCtrl.text = customer.address!;
      if (customer.vatNumber != null) _customerVatCtrl.text = customer.vatNumber!;
    });
  }

  void _onSiteSelected(Site? site) {
    if (site == null) return;
    setState(() {
      _selectedSite = site;
      if (_customerNameCtrl.text.trim().isEmpty && site.clientName != null && site.clientName!.isNotEmpty) {
        _customerNameCtrl.text = site.clientName!;
      }
      if (_descriptionCtrl.text.trim().isEmpty) {
        _descriptionCtrl.text = 'Contracting Services for ${site.name}';
      }
    });
  }

  Future<void> _quickAddNewCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final vatCtrl = TextEditingController();
    final key = GlobalKey<FormState>();

    final added = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer / Company Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: vatCtrl,
                decoration: const InputDecoration(labelText: 'VAT / Tax No', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2540)),
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              try {
                final inserted = await _supabase.from('customers').insert({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'vat_number': vatCtrl.text.trim().isEmpty ? null : vatCtrl.text.trim(),
                }).select().single();

                final newCust = Customer.fromJson(inserted);
                if (ctx.mounted) Navigator.pop(ctx, newCust);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Save Customer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (added != null) {
      setState(() {
        _availableCustomers.add(added);
        _availableCustomers.sort((a, b) => a.name.compareTo(b.name));
        _onCustomerSelected(added);
      });
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final custName = _customerNameCtrl.text.trim();
      String? custId = _selectedCustomer?.id;

      // If customer was entered manually and not in list, auto-create customer so they are stored
      if (custId == null && custName.isNotEmpty) {
        final existingMatch = _availableCustomers.where(
          (c) => c.name.toLowerCase() == custName.toLowerCase(),
        ).toList();

        if (existingMatch.isNotEmpty) {
          custId = existingMatch.first.id;
        } else {
          // Auto create customer record so they store for future selection
          try {
            final custRes = await _supabase.from('customers').insert({
              'name': custName,
              'phone': _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
              'address': _customerAddressCtrl.text.trim().isEmpty ? null : _customerAddressCtrl.text.trim(),
              'vat_number': _customerVatCtrl.text.trim().isEmpty ? null : _customerVatCtrl.text.trim(),
            }).select().single();
            custId = custRes['id']?.toString();
          } catch (_) {}
        }
      }

      final invoicePayload = {
        'invoice_number': _invoiceNumCtrl.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'due_date': _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
        'status': _status, // Pending or Paid
        'customer_id': custId,
        'customer_name': custName,
        'customer_phone': _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
        'customer_address': _customerAddressCtrl.text.trim().isEmpty ? null : _customerAddressCtrl.text.trim(),
        'customer_vat_number': _customerVatCtrl.text.trim().isEmpty ? null : _customerVatCtrl.text.trim(),
        'site_id': _selectedSite?.id,
        'site_name': _selectedSite?.name,
        'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        'subtotal': _subtotal,
        'discount': double.tryParse(_discountCtrl.text.trim()) ?? 0.0,
        'discount_type': _discountType,
        'vat_rate': double.tryParse(_vatRateCtrl.text.trim()) ?? 0.0,
        'vat_amount': _vatAmount,
        'total_amount': _grandTotal,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'payment_terms': _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
      };

      String invoiceId;
      if (widget.invoiceToEdit == null) {
        // Insert new invoice
        final res = await _supabase.from('invoices').insert(invoicePayload).select('id').single();
        invoiceId = res['id'].toString();
      } else {
        // Update existing invoice
        invoiceId = widget.invoiceToEdit!.id;
        await _supabase.from('invoices').update(invoicePayload).eq('id', invoiceId);
        // Clear old items
        await _supabase.from('invoice_items').delete().eq('invoice_id', invoiceId);
      }

      // Insert line items
      final itemsToInsert = <Map<String, dynamic>>[];
      for (int i = 0; i < _itemRows.length; i++) {
        final row = _itemRows[i];
        final desc = row.descriptionCtrl.text.trim();
        if (desc.isEmpty) continue;
        final qty = double.tryParse(row.qtyCtrl.text.trim()) ?? 1.0;
        final price = double.tryParse(row.priceCtrl.text.trim()) ?? 0.0;

        itemsToInsert.add({
          'invoice_id': invoiceId,
          'item_description': desc,
          'quantity': qty,
          'unit_price': price,
          'amount': qty * price,
          'sort_order': i,
        });
      }

      if (itemsToInsert.isNotEmpty) {
        await _supabase.from('invoice_items').insert(itemsToInsert);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.invoiceToEdit == null
                  ? 'Invoice created successfully (Status: $_status)'
                  : 'Invoice updated successfully',
            ),
            backgroundColor: const Color(0xFF137333),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.invoiceToEdit == null ? 'Create Invoice' : 'Edit Invoice',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveInvoice,
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save Invoice',
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Invoice Metadata Card (Number, Dates, Status)
                  _buildSectionCard(
                    title: 'Invoice Details',
                    icon: Icons.receipt_long_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _invoiceNumCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice Number *',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Status Dropdown
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _status == 'Paid'
                                      ? const Color(0xFFE6F4EA)
                                      : const Color(0xFFFFF0ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _status == 'Paid'
                                        ? const Color(0xFF137333)
                                        : const Color(0xFFD93025),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _status,
                                    isExpanded: true,
                                    items: [
                                      DropdownMenuItem(
                                        value: 'Pending',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.hourglass_empty_rounded, size: 16, color: Color(0xFFD93025)),
                                            SizedBox(width: 6),
                                            Text('Pending', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD93025))),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Paid',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF137333)),
                                            SizedBox(width: 6),
                                            Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _status = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Issue Date Picker
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _invoiceDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) setState(() => _invoiceDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Issue Date',
                                    prefixIcon: Icon(Icons.calendar_today_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(df.format(_invoiceDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Due Date Picker
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dueDate ?? _invoiceDate.add(const Duration(days: 14)),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) setState(() => _dueDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Due Date',
                                    prefixIcon: const Icon(Icons.event_available_rounded),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: _dueDate != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setState(() => _dueDate = null),
                                          )
                                        : null,
                                  ),
                                  child: Text(_dueDate != null ? df.format(_dueDate!) : 'Not set'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Customer & Site Card
                  _buildSectionCard(
                    title: 'Customer & Project Selection',
                    icon: Icons.person_pin_rounded,
                    headerAction: TextButton.icon(
                      onPressed: _quickAddNewCustomer,
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('+ New Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF0B5ED7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer dropdown from saved customers
                        if (_availableCustomers.isNotEmpty) ...[
                          DropdownButtonFormField<Customer>(
                            initialValue: _selectedCustomer,
                            decoration: const InputDecoration(
                              labelText: 'Select Saved Customer',
                              prefixIcon: Icon(Icons.groups_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: _availableCustomers.map((c) {
                              return DropdownMenuItem<Customer>(
                                value: c,
                                child: Text(c.name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: _onCustomerSelected,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Customer Name Field (Editable / Custom)
                        TextFormField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer / Company Name *',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Project / Site Dropdown (Optional)
                        DropdownButtonFormField<Site>(
                          initialValue: _selectedSite,
                          decoration: const InputDecoration(
                            labelText: 'Link to Site / Project (Optional)',
                            prefixIcon: Icon(Icons.business_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<Site>(
                              value: null,
                              child: Text('None (General Client)'),
                            ),
                            ..._availableSites.map((s) {
                              return DropdownMenuItem<Site>(
                                value: s,
                                child: Text('${s.name} (${s.code ?? 'Site'})', overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: _onSiteSelected,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _customerPhoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _customerVatCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'VAT / Tax No',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerAddressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer Address / Location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Invoice Subject / Description
                  _buildSectionCard(
                    title: 'Invoice Description / Subject',
                    icon: Icons.description_outlined,
                    child: TextFormField(
                      controller: _descriptionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Brief Description of Works / Services',
                        hintText: 'e.g., Construction of Boundary Wall & Ground Works',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Line Items Table / List
                  _buildSectionCard(
                    title: 'Invoice Line Items & Rates',
                    icon: Icons.format_list_bulleted_rounded,
                    headerAction: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _itemRows.add(_ItemInputRow(
                            descriptionCtrl: TextEditingController(),
                            qtyCtrl: TextEditingController(text: '1'),
                            priceCtrl: TextEditingController(text: '0'),
                          ));
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF0B5ED7)),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _itemRows.length; i++) ...[
                          _buildItemRowCard(i),
                          if (i < _itemRows.length - 1) const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                        // Subtotal line
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Line Items Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                currencyFormat.format(_subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2540)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Common Discount & VAT Section
                  _buildSectionCard(
                    title: 'Discount & VAT Settings',
                    icon: Icons.percent_rounded,
                    child: Column(
                      children: [
                        // Common Discount Area
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _discountCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Common Discount Area',
                                  prefixText: _discountType == 'amount' ? 'BHD ' : '',
                                  suffixText: _discountType == 'percentage' ? '%' : '',
                                  border: const OutlineInputBorder(),
                                  helperText: _discountType == 'percentage'
                                      ? 'Calculated: ${currencyFormat.format(_discountAmount)}'
                                      : null,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _discountType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'amount', child: Text('BHD Fixed')),
                                      DropdownMenuItem(value: 'percentage', child: Text('% Percent')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _discountType = v);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // VAT Rate
                        TextFormField(
                          controller: _vatRateCtrl,
                          decoration: InputDecoration(
                            labelText: 'VAT Rate (%)',
                            suffixText: '%',
                            border: const OutlineInputBorder(),
                            helperText: 'Calculated VAT: ${currencyFormat.format(_vatAmount)}',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Grand Total Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF0A2540), Colors.blue[900]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A2540).withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSummaryItem('Subtotal', currencyFormat.format(_subtotal), Colors.white70),
                        if (_discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _buildSummaryItem(
                            'Discount (${_discountType == 'percentage' ? '${_discountCtrl.text}%' : 'BHD'})',
                            '- ${currencyFormat.format(_discountAmount)}',
                            Colors.amberAccent,
                          ),
                        ],
                        if (_vatAmount > 0) ...[
                          const SizedBox(height: 6),
                          _buildSummaryItem(
                            'VAT (${_vatRateCtrl.text}%)',
                            '+ ${currencyFormat.format(_vatAmount)}',
                            Colors.cyanAccent,
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL DUE / PAYABLE',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                            ),
                            Text(
                              currencyFormat.format(_grandTotal),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: _status == 'Paid' ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              _status == 'Paid' ? 'STATUS: PAID' : 'STATUS: PENDING',
                              style: TextStyle(
                                color: _status == 'Paid' ? Colors.greenAccent : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notes & Terms Card
                  _buildSectionCard(
                    title: 'Terms & Notes',
                    icon: Icons.notes_rounded,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Remarks',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paymentTermsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Payment Terms / Methods',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveInvoice,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving
                            ? 'Saving Invoice...'
                            : (widget.invoiceToEdit == null ? 'Save Invoice (Pending)' : 'Update Invoice'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildItemRowCard(int index) {
    final row = _itemRows[index];
    final qty = double.tryParse(row.qtyCtrl.text.trim()) ?? 0.0;
    final price = double.tryParse(row.priceCtrl.text.trim()) ?? 0.0;
    final rowTotal = qty * price;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF0A2540),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item / Service Description *',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              if (_itemRows.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      row.dispose();
                      _itemRows.removeAt(index);
                    });
                  },
                  tooltip: 'Remove Item',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Req' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: row.priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    prefixText: 'BHD ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Req' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        currencyFormat.format(rowTotal),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? headerAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF0A2540)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                ],
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ItemInputRow {
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _ItemInputRow({
    required this.descriptionCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
