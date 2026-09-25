import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/income_budget_model.dart';
import 'budget_detail_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<IncomeSection>> _incomeSectionsFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 0);
  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  void _loadBudget() {
    setState(() {
      _incomeSectionsFuture = _fetchIncomeSections();
    });
  }

  Future<List<IncomeSection>> _fetchIncomeSections() async {
    final sectionsResponse = await _supabase
        .from('income_sections')
        .select()
        .order('date', ascending: false);

    final List<IncomeSection> result = [];

    for (final secJson in (sectionsResponse as List)) {
      final sectionId = secJson['id'].toString();
      final expensesResponse = await _supabase
          .from('income_expenses')
          .select()
          .eq('income_id', sectionId)
          .order('date', ascending: false);

      final expenses = (expensesResponse as List)
          .map((e) => IncomeExpense.fromJson(e))
          .toList();

      result.add(IncomeSection.fromJson(secJson, expenses));
    }

    return result;
  }

  // --- CREATE / EDIT BUDGET FILE ---
  void _showIncomeDialog([IncomeSection? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
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
            title: Text(existing == null ? 'Create Budget File' : 'Edit Budget File'),
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
                        hintText: 'e.g. Villa Project Budget, Advance Fund',
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
                            final title = titleCtrl.text.trim();
                            final amount = double.parse(amountCtrl.text.trim());
                            final notes = notesCtrl.text.trim();

                            final data = {
                              'title': title,
                              'amount': amount,
                              'date': selectedDate.toIso8601String().split('T').first,
                              'notes': notes.isEmpty ? null : notes,
                              'updated_at': DateTime.now().toIso8601String(),
                            };

                            if (existing == null) {
                              await _supabase.from('income_sections').insert(data);
                            } else {
                              await _supabase.from('income_sections').update(data).eq('id', existing.id);
                            }

                            nav.pop();
                            _loadBudget();
                            messenger.showSnackBar(
                              SnackBar(content: Text(existing == null ? 'Budget File created successfully' : 'Budget File updated')),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(existing == null ? 'Create File' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteIncome(IncomeSection section) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Budget File'),
        content: Text('Are you sure you want to delete "${section.title}" and all its spent items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await _supabase.from('income_sections').delete().eq('id', section.id);
                _loadBudget();
                messenger.showSnackBar(const SnackBar(content: Text('Budget file deleted')));
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

  void _openBudgetDetails(IncomeSection section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetDetailScreen(section: section),
      ),
    ).then((_) => _loadBudget());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Files', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBudget,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadBudget();
          await _incomeSectionsFuture;
        },
        child: FutureBuilder<List<IncomeSection>>(
          future: _incomeSectionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadBudget, child: const Text('Retry')),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Budget Files Created Yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a budget file to track income and spent items.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showIncomeDialog(),
                      icon: const Icon(Icons.create_new_folder_rounded),
                      label: const Text('Create First Budget File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              );
            }

            final sections = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Files & Folders',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tap file to view details',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Budget Files list
                ...sections.map((section) => _buildBudgetFileCard(section)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIncomeDialog(),
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Add Budget File'),
      ),
    );
  }

  Widget _buildBudgetFileCard(IncomeSection section) {
    final isNegative = section.remainingBalance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openBudgetDetails(section),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Folder Icon Banner
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_special_rounded,
                  color: Colors.amber.shade900,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),

              // File Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${dateFormat.format(section.date)} | ${section.expenses.length} ${section.expenses.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Income: ${currencyFormat.format(section.amount)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Spent: ${currencyFormat.format(section.totalSpent)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${currencyFormat.format(section.remainingBalance)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isNegative ? Colors.red : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),

              // Popup Actions Menu & Arrow
              Column(
                children: [
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'open') {
                        _openBudgetDetails(section);
                      } else if (val == 'edit') {
                        _showIncomeDialog(section);
                      } else if (val == 'delete') {
                        _confirmDeleteIncome(section);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.folder_open, size: 18),
                            SizedBox(width: 8),
                            Text('Open Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit File'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete File', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
