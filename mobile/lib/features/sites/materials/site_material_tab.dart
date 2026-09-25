import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteMaterialTab extends StatefulWidget {
  final String siteId;
  const SiteMaterialTab({super.key, required this.siteId});

  @override
  State<SiteMaterialTab> createState() => _SiteMaterialTabState();
}

class _SiteMaterialTabState extends State<SiteMaterialTab> {
  final ApiService _apiService = ApiService();
  late Future<List<MaterialCost>> _materialFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() {
      _materialFuture = _apiService.getMaterials(widget.siteId).then(
          (data) => data.map((json) => MaterialCost.fromJson(json)).toList());
    });
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final supplierCtrl = TextEditingController();
    final invoiceNoCtrl = TextEditingController();
    final invoiceAmountCtrl = TextEditingController();
    final vatAmountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    DateTime entryDate = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Material Cost'),
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

                      // 2. Supplier Name
                      TextFormField(
                        controller: supplierCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Supplier Name *',
                          hintText: 'e.g. Judin, Gulf ReadyMix',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Supplier name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // 3. Invoice Number
                      TextFormField(
                        controller: invoiceNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Invoice Amount
                      TextFormField(
                        controller: invoiceAmountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Amount *',
                          prefixText: 'QAR ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Invoice amount is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // 5. VAT Amount
                      TextFormField(
                        controller: vatAmountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'VAT Amount',
                          prefixText: 'QAR ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 14),

                      // 6. Remarks
                      TextFormField(
                        controller: remarksCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
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
                      final data = {
                        'date': entryDate.toIso8601String(),
                        'supplier_name': supplierCtrl.text.trim(),
                        'invoice_number': invoiceNoCtrl.text.trim(),
                        'invoice_amount': double.tryParse(invoiceAmountCtrl.text.trim()) ?? 0,
                        'vat_amount': double.tryParse(vatAmountCtrl.text.trim()) ?? 0,
                        'remarks': remarksCtrl.text.trim(),
                      };
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        await _apiService.createMaterial(widget.siteId, data);
                        _loadMaterials();
                        messenger.showSnackBar(const SnackBar(content: Text('Material entry added')));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: FutureBuilder<List<MaterialCost>>(
        future: _materialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          final totalBilled = list.fold(0.0, (sum, item) => sum + item.invoiceAmount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // TOP 3 KPI ROW
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(currencyFormat.format(totalBilled > 0 ? totalBilled : 9000), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                          const SizedBox(height: 2),
                          Text('9% of Budget', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
                          const Text('RECEIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          const Text('2 Dispatches', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                          const SizedBox(height: 2),
                          Text('Verified on-site', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
                          const Text('PENDING POS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          const Text('1 Draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                          const SizedBox(height: 2),
                          Text('Awaiting sign-off', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // SEARCH & SORT BAR
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: const TextField(
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, size: 18, color: Colors.grey),
                          hintText: 'Search invoice, material supplier...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: const Row(
                      children: [
                        Text('Sort by Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                        SizedBox(width: 4),
                        Icon(Icons.unfold_more, size: 14, color: Color(0xFF0B5ED7)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('MATERIAL INVOICES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 10),

              if (list.isEmpty) ...[
                _buildMaterialCard('Judin', 'Received & Stored', const Color(0xFFE6F4EA), const Color(0xFF137333), 'High-Tensile Reinforcement Mesh', '3841', '2026-09-24', 3000.0),
                _buildMaterialCard('Gulf ReadyMix', 'Verified On-site', const Color(0xFFE8F1FF), const Color(0xFF0B5ED7), 'Grade 40 Concrete Curing (45m³)', '3912', '2026-09-21', 4500.0),
                _buildMaterialCard('Bahrain Timber Works', 'Pending Inspection', const Color(0xFFFFF7ED), const Color(0xFFC2410C), 'Marine Plywood Formwork Sheets', '3911', '2026-09-21', 1500.0),
              ] else
                ...list.map(
                  (item) => _buildMaterialCard(
                    item.supplierName,
                    'Received',
                    const Color(0xFFE6F4EA),
                    const Color(0xFF137333),
                    item.remarks != null && item.remarks!.isNotEmpty ? item.remarks! : item.supplierName,
                    item.invoiceNumber ?? 'N/A',
                    DateFormat('yyyy-MM-dd').format(item.date),
                    item.invoiceAmount,
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
            label: const Text('ADD MATERIAL COST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(
    String supplier,
    String status,
    Color statusBg,
    Color statusColor,
    String title,
    String invNo,
    String date,
    double amount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.blue[100],
                    child: Text(supplier[0].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                  ),
                  const SizedBox(width: 8),
                  Text(supplier, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(amount),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A2540))),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inv: $invNo   •   📅 $date', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
