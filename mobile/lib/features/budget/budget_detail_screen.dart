import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/pie_chart_widget.dart';
import '../../models/income_budget_model.dart';
import '../../models/capital_bank_model.dart';
import '../../services/capital_budget_service.dart';

class BudgetDetailScreen extends StatefulWidget {
  final IncomeSection section;

  const BudgetDetailScreen({super.key, required this.section});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _capitalBudgetService = CapitalBudgetService();
  late IncomeSection _currentSection;
  late Future<List<IncomeExpense>> _expensesFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);
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

  // --- ADD / REDUCE BUDGET FILE MONEY ---
  void _showAdjustBudgetDialog({required bool isAdd}) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime txDate = DateTime.now();
    String? selectedBankId;
    String? selectedBankName;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    List<CapitalBank> banks = [];
    try {
      banks = await _capitalBudgetService.getBanks();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final title = isAdd ? 'Add Money to Budget File' : 'Reduce Budget File Money';
          final actionLabel = isAdd ? 'Add Money' : 'Reduce Money';
          final iconColor = isAdd ? Colors.green : Colors.red;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.1),
                  child: Icon(isAdd ? Icons.add : Icons.remove, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_currentSection.title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Total Income:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(
                            currencyFormat.format(_currentSection.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '${isAdd ? 'Addition' : 'Reduction'} Amount *',
                        prefixText: 'BHD ',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 2)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
                        if (!isAdd && n > _currentSection.amount) {
                          return 'Cannot reduce more than current total income (${currencyFormat.format(_currentSection.amount)})';
                        }
                        return null;
                      },
                    ),

                    // CAPITAL BANK SELECTION
                    if (banks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        value: selectedBankId,
                        decoration: InputDecoration(
                          labelText: isAdd ? 'Deduct from Capital Bank (Optional)' : 'Return Funds to Capital Bank (Optional)',
                          hintText: isAdd ? 'Select bank' : 'Select deposit bank',
                          prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(isAdd ? 'None / Direct External Source' : 'None / Direct Reduction'),
                          ),
                          ...banks.map((b) => DropdownMenuItem<String?>(
                                value: b.id,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(b.bankName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    Text(
                                      currencyFormat.format(b.balance),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: b.balance > 0 ? Colors.green[700] : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedBankId = val;
                            selectedBankName = val != null
                                ? banks
                                    .firstWhere(
                                      (b) => b.id == val,
                                      orElse: () => CapitalBank(id: '', bankName: '', balance: 0),
                                    )
                                    .bankName
                                : null;
                          });
                        },
                      ),
                      if (selectedBankId != null) ...[
                        const SizedBox(height: 6),
                        Builder(builder: (ctx) {
                          final chosen = banks.firstWhere(
                            (b) => b.id == selectedBankId,
                            orElse: () => CapitalBank(id: '', bankName: '', balance: 0),
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isAdd
                                        ? 'Amount will be deducted from ${chosen.bankName} (Current: ${currencyFormat.format(chosen.balance)})'
                                        : 'Amount will be deposited back into ${chosen.bankName} (Current: ${currencyFormat.format(chosen.balance)})',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],

                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reason / Remarks *',
                        hintText: isAdd ? 'e.g. Budget replenishment from bank' : 'e.g. Surplus refund to bank',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please specify reason' : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Transaction Date: ${dateFormat.format(txDate)}'),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: txDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => txDate = picked);
                        }
                      },
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final amount = double.parse(amountCtrl.text.trim());
                        final reason = reasonCtrl.text.trim();
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          final newAmount = isAdd ? (_currentSection.amount + amount) : (_currentSection.amount - amount);

                          // 1. Update company budget section amount
                          await _supabase.from('income_sections').update({
                            'amount': newAmount,
                            'updated_at': DateTime.now().toIso8601String(),
                          }).eq('id', _currentSection.id);

                          // 2. Adjust Capital Bank if selected
                          final bankIdToUse = selectedBankId;
                          if (bankIdToUse != null && bankIdToUse.isNotEmpty) {
                            if (isAdd) {
                              await _capitalBudgetService.deductForCompanyBudget(
                                bankId: bankIdToUse,
                                bankName: selectedBankName ?? 'Capital Bank',
                                incomeSectionId: _currentSection.id,
                                budgetTitle: _currentSection.title,
                                amount: amount,
                                date: txDate,
                                notes: reason,
                              );
                            } else {
                              await _capitalBudgetService.returnFromCompanyBudget(
                                bankId: bankIdToUse,
                                bankName: selectedBankName ?? 'Capital Bank',
                                incomeSectionId: _currentSection.id,
                                budgetTitle: _currentSection.title,
                                amount: amount,
                                date: txDate,
                                notes: reason,
                              );
                            }
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isAdd
                                  ? 'Added ${currencyFormat.format(amount)} to ${_currentSection.title}${selectedBankName != null ? ' & deducted from $selectedBankName' : ''}!'
                                  : 'Reduced ${currencyFormat.format(amount)} from ${_currentSection.title}${selectedBankName != null ? ' & returned to $selectedBankName' : ''}!'),
                            ),
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _loadExpenses();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(actionLabel),
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
                        prefixText: 'BHD ',
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
            icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            tooltip: 'Add Money',
            onPressed: () => _showAdjustBudgetDialog(isAdd: true),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            tooltip: 'Reduce Money',
            onPressed: () => _showAdjustBudgetDialog(isAdd: false),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAdjustBudgetDialog(isAdd: true),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('+ Add Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAdjustBudgetDialog(isAdd: false),
                                icon: const Icon(Icons.remove, size: 16),
                                label: const Text('- Reduce Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
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
