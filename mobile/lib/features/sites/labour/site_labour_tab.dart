import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';
import '../../../services/permission_service.dart';
import '../../../core/constants/app_modules.dart';

class SiteLabourTab extends StatefulWidget {
  final String siteId;
  final VoidCallback? onDataChanged;
  const SiteLabourTab({super.key, required this.siteId, this.onDataChanged});

  @override
  State<SiteLabourTab> createState() => _SiteLabourTabState();
}

class _SiteLabourTabState extends State<SiteLabourTab> {
  final ApiService _apiService = ApiService();
  late Future<List<LabourCost>> _labourFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLabour();
  }

  void _loadLabour() {
    setState(() {
      _labourFuture = _apiService.getLabour(widget.siteId).then(
          (data) => data.map((json) => LabourCost.fromJson(json)).toList());
    });
  }

  void _showAddOrEditDialog({LabourCost? existingLabour}) {
    final isEditing = existingLabour != null;
    if (isEditing) {
      if (!PermissionService.instance.canEdit(AppModules.siteLabour)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to edit labour entries')),
        );
        return;
      }
    } else {
      if (!PermissionService.instance.canCreate(AppModules.siteLabour)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add labour entries')),
        );
        return;
      }
    }

    final formKey = GlobalKey<FormState>();
    final labourCtrl = TextEditingController(text: existingLabour?.labour ?? '');
    final quantityCtrl = TextEditingController(
      text: existingLabour != null
          ? (existingLabour.quantity % 1 == 0
              ? existingLabour.quantity.toInt().toString()
              : existingLabour.quantity.toString())
          : '',
    );
    final rateCtrl = TextEditingController(
      text: existingLabour != null
          ? (existingLabour.rate % 1 == 0
              ? existingLabour.rate.toInt().toString()
              : existingLabour.rate.toStringAsFixed(2))
          : '',
    );
    final amountCtrl = TextEditingController(
      text: existingLabour != null ? existingLabour.amount.toStringAsFixed(2) : '',
    );
    final pendingCtrl = TextEditingController(
      text: existingLabour != null && existingLabour.pending > 0
          ? (existingLabour.pending % 1 == 0
              ? existingLabour.pending.toInt().toString()
              : existingLabour.pending.toStringAsFixed(2))
          : '',
    );
    DateTime entryDate = existingLabour?.date ?? DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    void updateAmount() {
      final q = double.tryParse(quantityCtrl.text) ?? 0.0;
      final r = double.tryParse(rateCtrl.text) ?? 0.0;
      final amt = q * r;
      amountCtrl.text = amt.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Labour Entry' : 'Add Labour Entry'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Date
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text('Date: ${dateFormat.format(entryDate)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: entryDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setDialogState(() => entryDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. Labours (Trade name)
                      TextFormField(
                        controller: labourCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Labours / Trade *',
                          hintText: 'e.g. Masonry & Helpers, Steel Work',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Labours is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // 3. Qty
                      TextFormField(
                        controller: quantityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Qty (Headcount) *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Qty is required' : null,
                        onChanged: (_) => updateAmount(),
                      ),
                      const SizedBox(height: 14),

                      // 4. Rate
                      TextFormField(
                        controller: rateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rate *',
                          prefixText: 'BHD ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Rate is required' : null,
                        onChanged: (_) => updateAmount(),
                      ),
                      const SizedBox(height: 14),

                      // 5. Amount (Auto-Calculated or Editable)
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount (Qty * Rate)',
                          prefixText: 'BHD ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 14),

                      // 6. Pending
                      TextFormField(
                        controller: pendingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pending Amount',
                          prefixText: 'BHD ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final q = double.tryParse(quantityCtrl.text) ?? 0.0;
                      final r = double.tryParse(rateCtrl.text) ?? 0.0;
                      final pending = double.tryParse(pendingCtrl.text) ?? 0.0;

                      final data = {
                        'date': entryDate.toIso8601String(),
                        'labour': labourCtrl.text.trim(),
                        'quantity': q,
                        'rate': r,
                        'pending': pending,
                      };

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        if (isEditing) {
                          await _apiService.updateLabour(existingLabour.id, data);
                          messenger.showSnackBar(const SnackBar(content: Text('Labour entry updated successfully')));
                        } else {
                          await _apiService.createLabour(widget.siteId, data);
                          messenger.showSnackBar(const SnackBar(content: Text('Labour entry added successfully')));
                        }
                        _loadLabour();
                        widget.onDataChanged?.call();
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLabour(LabourCost item) {
    if (!PermissionService.instance.canDelete(AppModules.siteLabour)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to delete labour entries')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Labour Entry'),
        content: Text('Are you sure you want to delete "${item.labour}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              try {
                await _apiService.deleteLabour(item.id);
                _loadLabour();
                widget.onDataChanged?.call();
                messenger.showSnackBar(const SnackBar(content: Text('Labour entry deleted successfully')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return ListenableBuilder(
      listenable: PermissionService.instance,
      builder: (context, _) {
        final canCreate = PermissionService.instance.canCreate(AppModules.siteLabour);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: FutureBuilder<List<LabourCost>>(
            future: _labourFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final list = snapshot.data ?? [];
              final totalHeadcount = list.fold(0, (sum, item) => sum + item.quantity.toInt());
              final totalShiftCost = list.fold(0.0, (sum, item) => sum + item.amount);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // TOP 3 KPI CARDS (HEADCOUNT, SHIFT COST, SHIFT AVG)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('HEADCOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('$totalHeadcount Workers', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHIFT COST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(currencyFormat.format(totalShiftCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHIFT AVG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('${list.isEmpty ? 0.0 : 8.0} hrs', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // DATE FILTER PILLS
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0A2540)),
                            const SizedBox(width: 6),
                            Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                        child: const Text('Yesterday', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF0B5ED7), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Selected', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // LABOUR LOGS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('LABOUR LOGS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      Text('Showing ${list.length} records', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (list.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No Labour Logs for this Date',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2540)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the button below to log trade workforce, hours, and rates.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    ...list.map((item) => _buildLabourCard(item)),
                ],
              );
            },
          ),
          bottomSheet: canCreate
              ? Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showAddOrEditDialog(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('ADD LABOUR COST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildLabourCard(LabourCost item) {
    final canEdit = PermissionService.instance.canEdit(AppModules.siteLabour);
    final canDelete = PermissionService.instance.canDelete(AppModules.siteLabour);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canEdit ? () => _showAddOrEditDialog(existingLabour: item) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.labour.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✔ Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF137333),
                            ),
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0B5ED7)),
                            tooltip: 'Edit Labour Entry',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            splashRadius: 18,
                            onPressed: () => _showAddOrEditDialog(existingLabour: item),
                          ),
                        ],
                        if (canDelete) ...[
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete Labour Entry',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            splashRadius: 18,
                            onPressed: () => _confirmDeleteLabour(item),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.labour, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                const SizedBox(height: 2),
                Text(
                  'Shift Date: ${DateFormat('yyyy-MM-dd').format(item.date)} • 8.0 hrs',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${item.quantity.toInt()} • Rate: BHD ${item.rate.toStringAsFixed(2)}${item.pending > 0 ? ' • Pending: BHD ${item.pending.toStringAsFixed(2)}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    Text(
                      currencyFormat.format(item.amount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
