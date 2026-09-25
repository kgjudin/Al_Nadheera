import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/financial_models.dart';

class SiteBudgetTab extends StatefulWidget {
  final String siteId;
  const SiteBudgetTab({super.key, required this.siteId});

  @override
  State<SiteBudgetTab> createState() => _SiteBudgetTabState();
}

class _SiteBudgetTabState extends State<SiteBudgetTab> {
  final ApiService _apiService = ApiService();
  late Future<List<SiteBudget>> _budgetFuture;
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  void _loadBudget() {
    setState(() {
      _budgetFuture = _apiService.getSiteBudget(widget.siteId).then(
          (data) => data.map((json) => SiteBudget.fromJson(json)).toList());
    });
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final incomeCameCtrl = TextEditingController();
    final incomeSpendCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Budget Entry'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: incomeCameCtrl,
                    decoration: const InputDecoration(labelText: 'Income Came'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextFormField(
                    controller: incomeSpendCtrl,
                    decoration: const InputDecoration(labelText: 'Income Spend'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'income_came': double.tryParse(incomeCameCtrl.text) ?? 0,
                    'income_spend': double.tryParse(incomeSpendCtrl.text) ?? 0,
                  };
                  Navigator.pop(context);
                  try {
                    await _apiService.createSiteBudget(widget.siteId, data);
                    _loadBudget();
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
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<SiteBudget>>(
            future: _budgetFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No budget entries yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Card(
                    child: ListTile(
                      title: Text('Balance: ${currencyFormat.format(item.balance)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Income Came: ${currencyFormat.format(item.incomeCame)} | '
                        'Income Spend: ${currencyFormat.format(item.incomeSpend)}',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('ADD ENTRY'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ],
    );
  }
}
