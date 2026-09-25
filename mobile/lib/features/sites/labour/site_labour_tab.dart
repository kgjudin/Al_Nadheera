import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteLabourTab extends StatefulWidget {
  final String siteId;
  const SiteLabourTab({super.key, required this.siteId});

  @override
  State<SiteLabourTab> createState() => _SiteLabourTabState();
}

class _SiteLabourTabState extends State<SiteLabourTab> {
  final ApiService _apiService = ApiService();
  late Future<List<LabourCost>> _labourFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);
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

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final labourCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final pendingCtrl = TextEditingController();
    DateTime entryDate = DateTime.now();
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
              title: const Text('Add Labour Entry'),
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
                          prefixText: 'QAR ',
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
                          prefixText: 'QAR ',
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
                          prefixText: 'QAR ',
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
                      final amt = double.tryParse(amountCtrl.text) ?? (q * r);
                      final pending = double.tryParse(pendingCtrl.text) ?? 0.0;

                      final data = {
                        'date': entryDate.toIso8601String(),
                        'labour': labourCtrl.text.trim(),
                        'quantity': q,
                        'rate': r,
                        'amount': amt,
                        'pending': pending,
                      };

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        await _apiService.createLabour(widget.siteId, data);
                        _loadLabour();
                        messenger.showSnackBar(const SnackBar(content: Text('Labour entry added')));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Save'),
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
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

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
                          Text('${totalHeadcount > 0 ? totalHeadcount : 10} Workers', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
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
                          Text(currencyFormat.format(totalShiftCost > 0 ? totalShiftCost : 3850), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
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
                          const Text('8.0 hrs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
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
                  const Text('Sort: By Trade ˅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                ],
              ),
              const SizedBox(height: 10),

              if (list.isEmpty) ...[
                _buildLabourCard('MASONRY & HELPERS', 'Rest ($dateStr)', 'Day Shift • 07:00 - 15:00 (8 hrs)', 3, 400.0, 1200.0, 0.0, true),
                _buildLabourCard('STEEL WORK', 'Steel Fixers & Riggers', 'Foundation Slab C • 8.0 hrs', 5, 350.0, 1750.0, 0.0, true),
                _buildLabourCard('MEP', 'Electricians & Technicians', 'Conduit Rough in Level 1 • 8.0 hrs', 2, 450.0, 900.0, 0.0, false),
              ] else
                ...list.map(
                  (item) => _buildLabourCard(
                    item.labour.toUpperCase(),
                    item.labour,
                    'Shift Date: ${DateFormat('yyyy-MM-dd').format(item.date)} • 8.0 hrs',
                    item.quantity.toInt(),
                    item.rate,
                    item.amount,
                    item.pending,
                    true,
                  ),
                ),
            ],
          );
        },
      ),
      bottomSheet: Container(
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
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('ADD LABOUR COST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildLabourCard(
    String tag,
    String title,
    String subtitle,
    int qty,
    double rate,
    double total,
    double pending,
    bool isVerified,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
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
                child: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFFE6F4EA) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isVerified ? '✔ Verified' : 'Supervisor Assigned',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isVerified ? const Color(0xFF137333) : const Color(0xFFC2410C)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: $qty • Rate: QAR ${rate.toStringAsFixed(2)}${pending > 0 ? ' • Pending: QAR ${pending.toStringAsFixed(2)}' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
              Text(
                currencyFormat.format(total),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
