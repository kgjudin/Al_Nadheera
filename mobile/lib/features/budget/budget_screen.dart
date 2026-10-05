import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/income_budget_model.dart';
import '../../models/site_model.dart';
import '../../services/site_budget_service.dart';
import 'budget_detail_screen.dart';
import 'site_budget_history_dialog.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final SiteBudgetService _siteBudgetService = SiteBudgetService();
  late TabController _tabController;

  late Future<List<IncomeSection>> _incomeSectionsFuture;
  late Future<List<Site>> _sitesFuture;

  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final currencyFormatWhole = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);
  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAllData() {
    setState(() {
      _incomeSectionsFuture = _fetchIncomeSections();
      _sitesFuture = _siteBudgetService.getSitesWithBudgets();
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

  // --- CREATE / EDIT COMPANY BUDGET FILE ---
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
                        prefixText: 'BHD ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter a valid positive number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${dateFormat.format(selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
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
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final title = titleCtrl.text.trim();
                        final amount = double.parse(amountCtrl.text.trim());
                        final notes = notesCtrl.text.trim();
                        final dateStr = selectedDate.toIso8601String().split('T').first;

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (existing == null) {
                            await _supabase.from('income_sections').insert({
                              'title': title,
                              'amount': amount,
                              'date': dateStr,
                              'notes': notes.isEmpty ? null : notes,
                            });
                            messenger.showSnackBar(const SnackBar(content: Text('Budget file created!')));
                          } else {
                            await _supabase.from('income_sections').update({
                              'title': title,
                              'amount': amount,
                              'date': dateStr,
                              'notes': notes.isEmpty ? null : notes,
                            }).eq('id', existing.id);
                            messenger.showSnackBar(const SnackBar(content: Text('Budget file updated!')));
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            _loadAllData();
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(SnackBar(content: Text('Error saving: $e')));
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ADD / REDUCE / SET SITE BUDGET DIALOG ---
  void _showSiteBudgetAdjustDialog(Site site, {required bool isAdd}) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime txDate = DateTime.now();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final title = isAdd ? 'Add Money to Site Budget' : 'Reduce Site Budget Money';
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
                      Text(site.name, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                          const Text('Current Assigned Budget:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(
                            currencyFormat.format(site.assignedBudget),
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
                        if (!isAdd && n > site.assignedBudget) {
                          return 'Cannot reduce more than current budget';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Remarks *',
                        hintText: 'e.g. Additional phase funding, Material adjustment',
                        border: OutlineInputBorder(),
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
                          if (isAdd) {
                            await _siteBudgetService.addBudget(
                              site: site,
                              amount: amount,
                              reason: reason,
                              date: txDate,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Successfully added ${currencyFormat.format(amount)} to ${site.name}!')),
                            );
                          } else {
                            await _siteBudgetService.reduceBudget(
                              site: site,
                              amount: amount,
                              reason: reason,
                              date: txDate,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Successfully reduced ${currencyFormat.format(amount)} from ${site.name}!')),
                            );
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            _loadAllData();
                          }
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

  // --- SET DIRECT SITE BUDGET DIALOG ---
  void _showSetSiteBudgetDialog(Site site) {
    final amountCtrl = TextEditingController(text: site.assignedBudget > 0 ? site.assignedBudget.toString() : '');
    final reasonCtrl = TextEditingController();
    DateTime txDate = DateTime.now();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.account_balance_wallet, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set Site Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(site.name, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                  children: [
                    TextFormField(
                      controller: amountCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'New Assigned Budget *',
                        prefixText: 'BHD ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Budget is required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Description *',
                        hintText: 'e.g. Initial contract assignment, Revision',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please specify reason' : null,
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
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final newBudget = double.parse(amountCtrl.text.trim());
                        final reason = reasonCtrl.text.trim();
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          await _siteBudgetService.setBudget(
                            site: site,
                            newBudget: newBudget,
                            reason: reason,
                            date: txDate,
                          );
                          messenger.showSnackBar(
                            SnackBar(content: Text('Budget updated for ${site.name}!')),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            _loadAllData();
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Set Budget'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSiteHistoryDialog(Site site) {
    showDialog(
      context: context,
      builder: (context) => SiteBudgetHistoryDialog(site: site),
    ).then((_) => _loadAllData());
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
                _loadAllData();
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
    ).then((_) => _loadAllData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.location_city_rounded), text: 'Site Budgets'),
            Tab(icon: Icon(Icons.folder_special_rounded), text: 'Company Budget Files'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Site Budgets Allocation & Audit
          _buildSiteBudgetsTab(),

          // TAB 2: Company Budget Files
          _buildCompanyBudgetFilesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            // Quick select site to assign or add budget
            _showQuickAssignSitePicker();
          } else {
            _showIncomeDialog();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Assign / Add Site Budget' : 'Add Budget File'),
      ),
    );
  }

  // --- TAB 1: SITE BUDGETS ---
  Widget _buildSiteBudgetsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
        await _sitesFuture;
      },
      child: FutureBuilder<List<Site>>(
        future: _sitesFuture,
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
                  Text('Error loading site budgets: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apartment_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Sites Found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create sites first to allocate budgets and record reports.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final sites = snapshot.data!;
          final totalBudget = sites.fold<double>(0.0, (sum, s) => sum + s.assignedBudget);
          final totalSpent = sites.fold<double>(0.0, (sum, s) => sum + s.spent);
          final totalBalance = totalBudget - totalSpent;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              Card(
                elevation: 0,
                color: const Color(0xFF0A2540),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Allocated Site Budgets',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(totalBudget),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Site Expenses', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(currencyFormat.format(totalSpent), style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Remaining Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormat.format(totalBalance),
                                style: TextStyle(
                                  color: totalBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 13,
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
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sites Budget Allocation',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${sites.length} sites',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...sites.map((site) => _buildSiteBudgetCard(site)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSiteBudgetCard(Site site) {
    final balance = site.assignedBudget - site.spent;
    final isNegative = balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Site Name & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.apartment_rounded, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (site.clientName != null && site.clientName!.isNotEmpty)
                              Text(
                                'Client: ${site.clientName}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: site.status == 'Active' ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    site.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: site.status == 'Active' ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Budget', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(site.assignedBudget),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Total Spent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(site.spent),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Remaining', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(balance),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isNegative ? Colors.red : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons: + Add Money, - Reduce Money, History/Report
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSiteBudgetAdjustDialog(site, isAdd: true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade800,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSiteBudgetAdjustDialog(site, isAdd: false),
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('- Reduce', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade800,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showSiteHistoryDialog(site),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Reports', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'set') {
                      _showSetSiteBudgetDialog(site);
                    } else if (val == 'history') {
                      _showSiteHistoryDialog(site);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'set',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Direct Set Budget'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 16),
                          SizedBox(width: 8),
                          Text('Budget Audit & PDF'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAssignSitePicker() async {
    final sites = await _sitesFuture;
    if (!mounted) return;
    if (sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sites available to assign budget.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Site to Assign / Top-Up Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sites.length,
                  itemBuilder: (context, i) {
                    final site = sites[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.apartment_rounded, size: 18)),
                      title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Current Budget: ${currencyFormat.format(site.assignedBudget)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(context);
                        _showSiteBudgetAdjustDialog(site, isAdd: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: COMPANY BUDGET FILES ---
  Widget _buildCompanyBudgetFilesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
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
                  ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
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
              const SizedBox(height: 80),
            ],
          );
        },
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
                          'Income: ${currencyFormatWhole.format(section.amount)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Spent: ${currencyFormatWhole.format(section.totalSpent)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${currencyFormatWhole.format(section.remainingBalance)}',
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
