import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteAdditionalExpenseTab extends StatefulWidget {
  final String siteId;
  const SiteAdditionalExpenseTab({super.key, required this.siteId});

  @override
  State<SiteAdditionalExpenseTab> createState() => _SiteAdditionalExpenseTabState();
}

class _SiteAdditionalExpenseTabState extends State<SiteAdditionalExpenseTab> {
  final ApiService _apiService = ApiService();
  late Future<List<AdditionalExpense>> _expensesFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    setState(() {
      _expensesFuture = _apiService.getAdditionalExpenses(widget.siteId).then(
          (data) => data.map((json) => AdditionalExpense.fromJson(json)).toList());
    });
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Additional Expense'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Expense Title *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount *', prefixText: 'QAR ', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'date': date.toIso8601String(),
                    'expense_title': titleCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0,
                    'remarks': remarksCtrl.text,
                  };
                  Navigator.pop(context);
                  try {
                    await _apiService.createAdditionalExpense(widget.siteId, data);
                    _loadExpenses();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: FutureBuilder<List<AdditionalExpense>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          final totalDisbursed = list.fold(0.0, (sum, item) => sum + item.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // ADDITIONAL EXPENSE SNAPSHOT CARD
              Container(
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
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF0B5ED7), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('Additional Expense Snapshot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                          ],
                        ),
                        Text('FY 2024/Q4', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contingency', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('QAR 16,667', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Disbursed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(currencyFormat.format(totalDisbursed > 0 ? totalDisbursed : 3333), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Pending', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            const Text('1 Claim', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // FILTER PILLS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All (${list.length > 0 ? list.length : 3})', _selectedFilter == 'All', () => setState(() => _selectedFilter = 'All')),
                    const SizedBox(width: 8),
                    _buildFilterPill('Permits & Fees', _selectedFilter == 'Permits', () => setState(() => _selectedFilter = 'Permits')),
                    const SizedBox(width: 8),
                    _buildFilterPill('Site Fuel & Gen', _selectedFilter == 'Fuel', () => setState(() => _selectedFilter = 'Fuel')),
                    const SizedBox(width: 8),
                    _buildFilterPill('Safety', _selectedFilter == 'Safety', () => setState(() => _selectedFilter = 'Safety')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (list.isEmpty) ...[
                _buildExpenseCard('Government & Statutory Permits', '✔ Paid', const Color(0xFFE6F4EA), const Color(0xFF137333), 'ddd (Municipality Permit & Staging Fee)', '3,333.00 QAR', '2026-09-24', 'CORP-4912', '📎 Receipt.pdf'),
                _buildExpenseCard('Utilities & Power', 'Review', const Color(0xFFE8F1FF), const Color(0xFF0B5ED7), 'Site Generator Diesel Delivery (500L)', '850.00 QAR', '2026-09-22', 'Direct Debit', '✔ Verified'),
                _buildExpenseCard('HSE & Safety', 'Approved', const Color(0xFFE6F4EA), const Color(0xFF137333), 'PPE & Fall Protection Harness Sets', '1,420.00 QAR', '2026-09-19', 'Petty Cash', '📎 Invoice_TR.jpg'),
              ] else
                ...list.map(
                  (item) => _buildExpenseCard(
                    'Site Expense',
                    'Paid',
                    const Color(0xFFE6F4EA),
                    const Color(0xFF137333),
                    item.expenseTitle,
                    currencyFormat.format(item.amount),
                    DateFormat('yyyy-MM-dd').format(item.date),
                    'Petty Cash',
                    'Verified',
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
            label: const Text('ADD EXPENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2540) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0A2540) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(
    String category,
    String status,
    Color statusBg,
    Color statusColor,
    String title,
    String amount,
    String date,
    String paymentMethod,
    String attachment,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                  const SizedBox(width: 8),
                  Text(amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                ],
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
              Text('📅 $date   •   $paymentMethod', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Text(attachment, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
