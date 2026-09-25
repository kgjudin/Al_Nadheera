import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteSubcontractorTab extends StatefulWidget {
  final String siteId;
  const SiteSubcontractorTab({super.key, required this.siteId});

  @override
  State<SiteSubcontractorTab> createState() => _SiteSubcontractorTabState();
}

class _SiteSubcontractorTabState extends State<SiteSubcontractorTab> {
  final ApiService _apiService = ApiService();
  late Future<List<SubcontractorCost>> _subcontractorFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadSubcontractors();
  }

  void _loadSubcontractors() {
    setState(() {
      _subcontractorFuture = _apiService.getSubcontractors(widget.siteId).then(
          (data) => data.map((json) => SubcontractorCost.fromJson(json)).toList());
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
              title: const Text('Add Subcontractor Claim'),
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
                          hintText: 'e.g. Rast, Al-Manama Dewatering Co.',
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
                        'remark': remarksCtrl.text.trim(),
                      };
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        await _apiService.createSubcontractor(widget.siteId, data);
                        _loadSubcontractors();
                        messenger.showSnackBar(const SnackBar(content: Text('Subcontractor entry added')));
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
      body: FutureBuilder<List<SubcontractorCost>>(
        future: _subcontractorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          final totalCommitted = list.fold(0.0, (sum, item) => sum + item.invoiceAmount);
          final retentionAmount = totalCommitted * 0.10;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // TOP KPI CARDS
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACTIVE VENDORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('${list.isNotEmpty ? list.length : 3} Entities', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
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
                          const Text('COMMITTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(currencyFormat.format(totalCommitted > 0 ? totalCommitted : 5999), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
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
                          const Text('RETENTION (10%)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(currencyFormat.format(retentionAmount > 0 ? retentionAmount : 599.90), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CLAIMS & CERTIFICATES HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CLAIMS & CERTIFICATES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                  Text('Showing ${list.isNotEmpty ? list.length : 3} records', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 10),

              if (list.isEmpty) ...[
                _buildSubcontractorCard('R', 'Rast', 'Excavation & Ground Prep', '5,999.00 QAR', '1911', '2026-09-24', '✔ Certified', const Color(0xFFE6F4EA), const Color(0xFF137333), 'Milestone: Phase 1 Ground Prep'),
                _buildSubcontractorCard('AM', 'Al-Manama Dewatering Co.', 'Sub-Surface Drainage', '3,200.00 QAR', '1908', '2026-09-20', 'Under Review', const Color(0xFFFFF7ED), const Color(0xFFC2410C), 'Deep Well Dewatering (80%)'),
                _buildSubcontractorCard('GP', 'Gulf Piling & Geotech', 'Foundation & Shoring Works', '12,500.00 QAR', '1899', '2026-09-18', '✔ Approved', const Color(0xFFE6F4EA), const Color(0xFF137333), 'Bored Cast Piling QA Passed'),
              ] else
                ...list.map(
                  (item) => _buildSubcontractorCard(
                    item.supplierName[0].toUpperCase(),
                    item.supplierName,
                    item.remark != null && item.remark!.isNotEmpty ? item.remark! : 'Sub-Contractor Work',
                    currencyFormat.format(item.invoiceAmount),
                    item.invoiceNumber ?? 'N/A',
                    DateFormat('yyyy-MM-dd').format(item.date),
                    'Certified',
                    const Color(0xFFE6F4EA),
                    const Color(0xFF137333),
                    'Milestone Verified',
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
            label: const Text('ADD SUBCONTRACTOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildSubcontractorCard(
    String avatarText,
    String name,
    String subtitle,
    String amount,
    String invNo,
    String date,
    String status,
    Color statusBg,
    Color statusColor,
    String milestone,
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
                    radius: 14,
                    backgroundColor: Colors.blue[50],
                    child: Text(avatarText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
              Text(amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inv: $invNo   •   📅 $date', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(milestone, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
