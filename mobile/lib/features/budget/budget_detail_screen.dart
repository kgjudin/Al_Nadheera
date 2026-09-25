import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/pie_chart_widget.dart';
import '../../models/income_budget_model.dart';

class BudgetDetailScreen extends StatefulWidget {
  final IncomeSection section;

  const BudgetDetailScreen({super.key, required this.section});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final _supabase = Supabase.instance.client;
  late IncomeSection _currentSection;
  late Future<List<IncomeExpense>> _expensesFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 0);
  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _currentSection = widget.section;
    _loadExpenses();
  }

  void _loadExpenses() {
    setState(() {
      _expensesFuture = _fetchExpenses();
    });
  }

  Future<List<IncomeExpense>> _fetchExpenses() async {
    // Refresh section info as well
    final secResponse = await _supabase
        .from('income_sections')
        .select()
        .eq('id', _currentSection.id)
        .maybeSingle();

    final expensesResponse = await _supabase
        .from('income_expenses')
        .select()
        .eq('income_id', _currentSection.id)
        .order('date', ascending: false);

    final expensesList = (expensesResponse as List)
        .map((e) => IncomeExpense.fromJson(e))
        .toList();

    if (secResponse != null) {
      _currentSection = IncomeSection.fromJson(secResponse, expensesList);
    }

    return expensesList;
  }

  // --- EDIT INCOME SECTION ---
  void _showEditIncomeDialog() {
    final titleCtrl = TextEditingController(text: _currentSection.title);
    final amountCtrl = TextEditingController(text: _currentSection.amount.toString());
    final notesCtrl = TextEditingController(text: _currentSection.notes ?? '');
    DateTime selectedDate = _currentSection.date;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Budget File'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Budget File Title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Income Amount *',
                        prefixText: 'QAR ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text('Date: ${dateFormat.format(selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(dialogContext);

                          try {
                            final data = {
                              'title': titleCtrl.text.trim(),
                              'amount': double.parse(amountCtrl.text.trim()),
                              'date': selectedDate.toIso8601String().split('T').first,
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              'updated_at': DateTime.now().toIso8601String(),
                            };

                            await _supabase.from('income_sections').update(data).eq('id', _currentSection.id);

                            nav.pop();
                            _loadExpenses();
                            messenger.showSnackBar(const SnackBar(content: Text('Budget file updated')));
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ADD / EDIT EXPENSE (INCOME GONE) ---
  void _showExpenseDialog([IncomeExpense? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Expense (Income Gone)' : 'Edit Expense'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Expense Detail / Title *',
                        hintText: 'e.g. Cement Purchase, Worker Payment',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Detail is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Spent Amount (Income Gone) *',
                        prefixText: 'QAR ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Spent amount is required';
                        if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text('Spent Date: ${dateFormat.format(selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        hintText: 'e.g. Material, Labour, Transport',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(dialogContext);

                          try {
                            final data = {
                              'income_id': _currentSection.id,
                              'title': titleCtrl.text.trim(),
                              'amount': double.parse(amountCtrl.text.trim()),
                              'date': selectedDate.toIso8601String().split('T').first,
                              'category': categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              'updated_at': DateTime.now().toIso8601String(),
                            };

                            if (existing == null) {
                              await _supabase.from('income_expenses').insert(data);
                            } else {
                              await _supabase.from('income_expenses').update(data).eq('id', existing.id);
                            }

                            nav.pop();
                            _loadExpenses();
                            messenger.showSnackBar(
                              SnackBar(content: Text(existing == null ? 'Expense added' : 'Expense updated')),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(existing == null ? 'Add Expense' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteExpense(IncomeExpense expense) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await _supabase.from('income_expenses').delete().eq('id', expense.id);
                _loadExpenses();
                messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSection.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Budget File',
            onPressed: _showEditIncomeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadExpenses();
          await _expensesFuture;
        },
        child: FutureBuilder<List<IncomeExpense>>(
          future: _expensesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final expenses = snapshot.data ?? [];
            final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
            final remainingBalance = _currentSection.amount - totalSpent;
            final isOverBudget = remainingBalance < 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Budget Details Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.blue[900],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DATE: ${dateFormat.format(_currentSection.date)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.folder_open, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Budget File', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentSection.title,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (_currentSection.notes != null && _currentSection.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_currentSection.notes!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Income', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(_currentSection.amount),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(totalSpent),
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(remainingBalance),
                                  style: TextStyle(
                                    color: isOverBudget ? Colors.redAccent : Colors.greenAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pie Chart Breakdown
                PieChartWidget(
                  totalIncome: _currentSection.amount,
                  expenses: expenses,
                ),
                const SizedBox(height: 20),

                // Spent List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent Items (${expenses.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showExpenseDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Spent Item'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (expenses.isEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No spent items inside this budget file yet.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showExpenseDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Spent Item'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...expenses.map(
                    (exp) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[50],
                          child: const Icon(Icons.arrow_downward_rounded, color: Colors.red),
                        ),
                        title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('Spent Date: ${dateFormat.format(exp.date)}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            if (exp.category != null && exp.category!.isNotEmpty)
                              Text('Category: ${exp.category}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            if (exp.notes != null && exp.notes!.isNotEmpty)
                              Text('Notes: ${exp.notes}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '- ${currencyFormat.format(exp.amount)}',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showExpenseDialog(exp);
                                } else if (val == 'delete') {
                                  _confirmDeleteExpense(exp);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Spent Item'),
      ),
    );
  }
}
