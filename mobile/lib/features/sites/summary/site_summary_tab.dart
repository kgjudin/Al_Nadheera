import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteSummaryTab extends StatefulWidget {
  final String siteId;
  const SiteSummaryTab({super.key, required this.siteId});

  @override
  State<SiteSummaryTab> createState() => _SiteSummaryTabState();
}

class _SiteSummaryTabState extends State<SiteSummaryTab> {
  final ApiService _apiService = ApiService();
  late Future<List<SiteSummary>> _summaryFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    setState(() {
      _summaryFuture = _apiService.getSiteSummary(widget.siteId).then(
          (data) => data.map((json) => SiteSummary.fromJson(json)).toList());
    });
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final receivedCtrl = TextEditingController();
    final expensesCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    DateTime entryDate = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    void updateBalance() {
      final rec = double.tryParse(receivedCtrl.text) ?? 0.0;
      final exp = double.tryParse(expensesCtrl.text) ?? 0.0;
      final bal = rec - exp;
      balanceCtrl.text = bal.toStringAsFixed(2);
      amountCtrl.text = exp.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Summary Entry'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Date Picker
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

                      // 2. Received Amount (Given Amount)
                      TextFormField(
                        controller: receivedCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Received Amount (Given Amount) *',
                          prefixText: 'QAR ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => updateBalance(),
                      ),
                      const SizedBox(height: 14),

                      // 3. Cash Expense (Spend Amount)
                      TextFormField(
                        controller: expensesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cash Expense (Spend Amount) *',
                          prefixText: 'QAR ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => updateBalance(),
                      ),
                      const SizedBox(height: 14),

                      // 4. Amount (Spend Amount)
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount (Spend Amount)',
                          prefixText: 'QAR ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 14),

                      // 5. Balance (Given - Spend)
                      TextFormField(
                        controller: balanceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Balance (Given - Spend)',
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
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final rec = double.tryParse(receivedCtrl.text) ?? 0.0;
                      final exp = double.tryParse(expensesCtrl.text) ?? 0.0;
                      final amt = double.tryParse(amountCtrl.text) ?? exp;
                      final bal = double.tryParse(balanceCtrl.text) ?? (rec - exp);

                      final data = {
                        'date': entryDate.toIso8601String(),
                        'received_amount': rec,
                        'cash_expenses': exp,
                        'amount': amt,
                        'balance': bal,
                      };

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      try {
                        await _apiService.createSiteSummary(widget.siteId, data);
                        _loadSummary();
                        messenger.showSnackBar(const SnackBar(content: Text('Summary entry added')));
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
      body: FutureBuilder<List<SiteSummary>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          final totalReceived = list.fold(0.0, (sum, item) => sum + item.receivedAmount);
          final totalExpenses = list.fold(0.0, (sum, item) => sum + item.cashExpenses);
          final netBalance = totalReceived - totalExpenses;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // LEDGER DATE SELECTOR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LEDGER DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0A2540)),
                            const SizedBox(width: 6),
                            Text(dateStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setState(() => _selectedDate = DateTime.now());
                          },
                          child: const Text('< Today >', style: TextStyle(fontSize: 12, color: Color(0xFF0B5ED7), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2 TOP KPI CARDS: Given Amount & Spend Amount
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00C853), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('Given Amount', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(totalReceived),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                          ),
                          const SizedBox(height: 4),
                          Text('${list.length} Given inflows', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
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
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('Spend Amount', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(totalExpenses),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          const SizedBox(height: 4),
                          Text('Cash expenses spent', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // NET BALANCE BANNER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NET BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333), letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(netBalance),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Given - Spend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // PROJECT EXECUTION STATUS BOX
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
                        const Row(
                          children: [
                            Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0B5ED7)),
                            SizedBox(width: 6),
                            Text('Project Execution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2540))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('10% Completed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00C853), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('On Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
                        const Text('  •  Phase: Foundation & Substructure', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // RECENT ACTIVITY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                  InkWell(
                    onTap: () {},
                    child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (list.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text('No summary entries yet.', style: TextStyle(color: Colors.grey[600]))),
                )
              else
                ...list.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFFE6F4EA), shape: BoxShape.circle),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF137333), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Date: ${DateFormat('yyyy-MM-dd').format(item.date)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2540)),
                                ),
                              ],
                            ),
                            Text(
                              'Bal: ${currencyFormat.format(item.balance)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B5ED7)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Spend Amount', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '-${currencyFormat.format(item.cashExpenses)}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Balance', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(item.balance),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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
            label: const Text('ADD ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
