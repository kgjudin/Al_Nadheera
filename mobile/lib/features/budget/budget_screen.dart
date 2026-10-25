import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/income_budget_model.dart';
import '../../models/site_model.dart';
import '../../models/capital_bank_model.dart';
import '../../services/site_budget_service.dart';
import '../../services/capital_budget_service.dart';
import 'budget_detail_screen.dart';
import 'site_budget_history_dialog.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final SiteBudgetService _siteBudgetService = SiteBudgetService();
  final CapitalBudgetService _capitalBudgetService = CapitalBudgetService();
  late TabController _tabController;

  late Future<List<IncomeSection>> _incomeSectionsFuture;
  late Future<List<Site>> _sitesFuture;
  late Future<List<CapitalBank>> _banksFuture;
  List<CapitalBank> _cachedBanks = [];

  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final currencyFormatWhole = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);
  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
      _banksFuture = _capitalBudgetService.getBanks().then((list) {
        if (mounted) {
          setState(() {
            _cachedBanks = list;
          });
        }
        return list;
      });
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

  // --- CREATE COMPANY BUDGET FILE ---
  void _showIncomeDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedBankId;
    String? selectedBankName;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create Company Budget File',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

                    // SOURCE CAPITAL BANK SELECTOR
                    if (_cachedBanks.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        value: selectedBankId,
                        decoration: const InputDecoration(
                          labelText: 'Source Capital Bank (Deduct from)',
                          hintText: 'Select bank to take funds from',
                          prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None / Direct External Source'),
                          ),
                          ..._cachedBanks.map((b) => DropdownMenuItem<String?>(
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
                                ? _cachedBanks
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
                          final chosen = _cachedBanks.firstWhere(
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
                                    'Amount will be deducted from ${chosen.bankName} (Current: ${currencyFormat.format(chosen.balance)})',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                    ],

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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2540),
                  foregroundColor: Colors.white,
                ),
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
                          final res = await _supabase.from('income_sections').insert({
                            'title': title,
                            'amount': amount,
                            'date': dateStr,
                            'notes': notes.isEmpty ? null : notes,
                            'bank_id': selectedBankId,
                            'bank_name': selectedBankName,
                          }).select().single();

                          // Deduct from Capital Bank if selected
                          final bankIdToDeduct = selectedBankId;
                          if (bankIdToDeduct != null && bankIdToDeduct.isNotEmpty && amount > 0) {
                            await _capitalBudgetService.deductForCompanyBudget(
                              bankId: bankIdToDeduct,
                              bankName: selectedBankName ?? 'Capital Bank',
                              incomeSectionId: res['id'].toString(),
                              budgetTitle: title,
                              amount: amount,
                              date: selectedDate,
                              notes: notes.isEmpty ? null : notes,
                            );
                          }
                          messenger.showSnackBar(SnackBar(
                            content: Text(selectedBankName != null && amount > 0
                                ? 'Budget file created & deducted from $selectedBankName!'
                                : 'Budget file created!'),
                          ));

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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ADD / REDUCE COMPANY BUDGET FILE MONEY ---
  void _showCompanyBudgetAdjustDialog(IncomeSection section, {required bool isAdd}) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime txDate = DateTime.now();
    String? selectedBankId;
    String? selectedBankName;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final title = isAdd ? 'Add Money to Company Budget' : 'Reduce Company Budget Money';
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
                      Text(section.title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Current File Income:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text(
                                currencyFormat.format(section.amount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Balance:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                currencyFormat.format(section.remainingBalance),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: section.remainingBalance < 0 ? Colors.red : Colors.green[800],
                                ),
                              ),
                            ],
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
                        if (!isAdd && n > section.amount) {
                          return 'Cannot reduce more than current total income (${currencyFormat.format(section.amount)})';
                        }
                        return null;
                      },
                    ),

                    // CAPITAL BANK SELECTION
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: selectedBankId,
                      decoration: InputDecoration(
                        labelText: isAdd ? 'Deduct from Capital Bank (Optional)' : 'Return Funds to Capital Bank (Optional)',
                        hintText: isAdd ? 'Select source bank' : 'Select deposit bank',
                        prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(isAdd ? 'None / Direct External Source' : 'None / Direct Reduction'),
                        ),
                        ..._cachedBanks.map((b) => DropdownMenuItem<String?>(
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
                              ? _cachedBanks
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
                        final chosen = _cachedBanks.firstWhere(
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
                          final newAmount = isAdd ? (section.amount + amount) : (section.amount - amount);

                          // 1. Update company budget section amount
                          await _supabase.from('income_sections').update({
                            'amount': newAmount,
                            'updated_at': DateTime.now().toIso8601String(),
                          }).eq('id', section.id);

                          // 2. Adjust Capital Bank if selected
                          final bankIdToUse = selectedBankId;
                          if (bankIdToUse != null && bankIdToUse.isNotEmpty) {
                            if (isAdd) {
                              await _capitalBudgetService.deductForCompanyBudget(
                                bankId: bankIdToUse,
                                bankName: selectedBankName ?? 'Capital Bank',
                                incomeSectionId: section.id,
                                budgetTitle: section.title,
                                amount: amount,
                                date: txDate,
                                notes: reason,
                              );
                            } else {
                              await _capitalBudgetService.returnFromCompanyBudget(
                                bankId: bankIdToUse,
                                bankName: selectedBankName ?? 'Capital Bank',
                                incomeSectionId: section.id,
                                budgetTitle: section.title,
                                amount: amount,
                                date: txDate,
                                notes: reason,
                              );
                            }
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isAdd
                                  ? 'Added ${currencyFormat.format(amount)} to ${section.title}${selectedBankName != null ? ' & deducted from $selectedBankName' : ''}!'
                                  : 'Reduced ${currencyFormat.format(amount)} from ${section.title}${selectedBankName != null ? ' & returned to $selectedBankName' : ''}!'),
                            ),
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(actionLabel),
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
    String? selectedBankId;
    String? selectedBankName;
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

                    // WHICH BANK TO DEDUCT FROM (When adding money)
                    if (isAdd) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        value: selectedBankId,
                        decoration: const InputDecoration(
                          labelText: 'Deduct from Capital Bank (Optional)',
                          hintText: 'Select source bank',
                          prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None / Direct External Source'),
                          ),
                          ..._cachedBanks.map((b) => DropdownMenuItem<String?>(
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
                                ? _cachedBanks
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
                          final chosen = _cachedBanks.firstWhere(
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
                                    'Amount will be deducted from ${chosen.bankName} (Current: ${currencyFormat.format(chosen.balance)})',
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
                              bankId: selectedBankId,
                              bankName: selectedBankName,
                            );
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(selectedBankName != null
                                    ? 'Added ${currencyFormat.format(amount)} to ${site.name} & deducted from $selectedBankName!'
                                    : 'Successfully added ${currencyFormat.format(amount)} to ${site.name}!'),
                              ),
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

  // ========================================================
  // --- CAPITAL BUDGET (BANK MANAGEMENT) DIALOGS ---
  // ========================================================

  void _showAddEditBankDialog([CapitalBank? existingBank]) {
    final nameCtrl = TextEditingController(text: existingBank?.bankName ?? '');
    final accCtrl = TextEditingController(text: existingBank?.accountNumber ?? '');
    final balanceCtrl = TextEditingController(
      text: existingBank != null ? existingBank.balance.toString() : '',
    );
    final notesCtrl = TextEditingController(text: existingBank?.notes ?? '');
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
                CircleAvatar(
                  backgroundColor: const Color(0xFF0A2540).withValues(alpha: 0.1),
                  child: const Icon(Icons.account_balance, color: Color(0xFF0A2540)),
                ),
                const SizedBox(width: 12),
                Text(
                  existingBank == null ? 'Add Capital Bank' : 'Edit Bank Details',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name *',
                        hintText: 'e.g. BBK, NBB, Ahli United Bank',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Bank name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: accCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Number / IBAN (Optional)',
                        hintText: 'e.g. BH29NBB000000123456789',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (existingBank == null) ...[
                      TextFormField(
                        controller: balanceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Initial Capital Balance *',
                          prefixText: 'BHD ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Initial balance is required';
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks (Optional)',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2540),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final name = nameCtrl.text.trim();
                        final acc = accCtrl.text.trim();
                        final notes = notesCtrl.text.trim();
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          if (existingBank == null) {
                            final initBal = double.parse(balanceCtrl.text.trim());
                            await _capitalBudgetService.createBank(
                              bankName: name,
                              accountNumber: acc.isEmpty ? null : acc,
                              initialBalance: initBal,
                              notes: notes.isEmpty ? null : notes,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Bank "$name" created with BHD $initBal capital!')),
                            );
                          } else {
                            await _capitalBudgetService.updateBank(
                              id: existingBank.id,
                              bankName: name,
                              accountNumber: acc.isEmpty ? null : acc,
                              notes: notes.isEmpty ? null : notes,
                            );
                            messenger.showSnackBar(const SnackBar(content: Text('Bank details updated!')));
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _loadAllData();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(existingBank == null ? 'Add Bank' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBankAddReduceMoneyDialog(CapitalBank bank, {required bool isAdd}) {
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
          final title = isAdd ? 'Add Money to ${bank.bankName}' : 'Reduce Money from ${bank.bankName}';
          final actionLabel = isAdd ? 'Add Capital' : 'Reduce Capital';
          final iconColor = isAdd ? Colors.green : Colors.red;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.1),
                  child: Icon(isAdd ? Icons.arrow_downward : Icons.arrow_upward, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Current Balance: ${currencyFormat.format(bank.balance)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                      decoration: InputDecoration(
                        labelText: '${isAdd ? 'Deposit' : 'Withdrawal'} Amount *',
                        prefixText: 'BHD ',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 2)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Amount is required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
                        if (!isAdd && n > bank.balance) {
                          return 'Cannot reduce more than current available balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: isAdd ? 'Source / Deposit Reason *' : 'Drawdown / Reason *',
                        hintText: isAdd ? 'e.g. Shareholder capital injection' : 'e.g. Cash withdrawal, settlement',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please specify reason' : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${dateFormat.format(txDate)}'),
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
                            await _capitalBudgetService.addMoney(
                              bank: bank,
                              amount: amount,
                              reason: reason,
                              date: txDate,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Added ${currencyFormat.format(amount)} to ${bank.bankName}!')),
                            );
                          } else {
                            await _capitalBudgetService.reduceMoney(
                              bank: bank,
                              amount: amount,
                              reason: reason,
                              date: txDate,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Reduced ${currencyFormat.format(amount)} from ${bank.bankName}!')),
                            );
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _loadAllData();
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

  void _showBankTransactionsHistoryDialog(CapitalBank bank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                        ),
                        if (bank.accountNumber != null && bank.accountNumber!.isNotEmpty)
                          Text('Acc: ${bank.accountNumber}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bank.balance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: bank.balance >= 0 ? Colors.green.shade200 : Colors.red.shade200),
                    ),
                    child: Text(
                      currencyFormat.format(bank.balance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: bank.balance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Capital Activity & Disbursements Audit Log:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 20),
              Expanded(
                child: FutureBuilder<List<CapitalBankTransaction>>(
                  future: _capitalBudgetService.getTransactions(bankId: bank.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final txs = snapshot.data ?? [];
                    if (txs.isEmpty) {
                      return Center(
                        child: Text(
                          'No transactions recorded for this bank yet.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: txs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final tx = txs[i];
                        final isCredit = tx.isCredit;

                        IconData icon;
                        Color iconColor;
                        String typeLabel;

                        if (tx.transactionType == 'deposit') {
                          icon = Icons.add_circle_outline;
                          iconColor = Colors.green;
                          typeLabel = 'Deposit';
                        } else if (tx.transactionType == 'withdrawal') {
                          icon = Icons.remove_circle_outline;
                          iconColor = Colors.orange;
                          typeLabel = 'Withdrawal';
                        } else if (tx.transactionType == 'site_allocation') {
                          icon = Icons.location_city_rounded;
                          iconColor = Colors.blue;
                          typeLabel = 'Site Transfer';
                        } else {
                          icon = Icons.folder_special_rounded;
                          iconColor = Colors.purple;
                          typeLabel = 'Company Transfer';
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                          title: Text(
                            tx.referenceTitle ?? typeLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${dateFormat.format(tx.date)} • Bal: ${currencyFormat.format(tx.balanceAfter)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          trailing: Text(
                            '${isCredit ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isCredit ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                        );
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

  void _confirmDeleteBank(CapitalBank bank) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Capital Bank'),
        content: Text('Are you sure you want to delete "${bank.bankName}" and all its transaction history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await _capitalBudgetService.deleteBank(bank.id);
                _loadAllData();
                messenger.showSnackBar(const SnackBar(content: Text('Bank deleted successfully')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
            Tab(icon: Icon(Icons.folder_special_rounded), text: 'Company Budget'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Capital Budget'),
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

          // TAB 3: Capital Budget & Bank Accounts
          _buildCapitalBudgetTab(),
        ],
      ),
      floatingActionButton: PermissionService.instance.canCreate(AppModules.budget)
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showQuickAssignSitePicker();
                } else if (_tabController.index == 1) {
                  _showIncomeDialog();
                } else {
                  _showAddEditBankDialog();
                }
              },
              backgroundColor: const Color(0xFF0A2540),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                _tabController.index == 0
                    ? 'Assign / Add Site Budget'
                    : (_tabController.index == 1 ? 'Add Budget File' : 'Add Bank'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (site.code != null && site.code!.isNotEmpty)
                        Text(
                          'Code: ${site.code} • ${site.clientName ?? 'No Client'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: site.status == 'Ongoing' ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    site.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: site.status == 'Ongoing' ? Colors.blue.shade700 : Colors.green.shade700,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_special_rounded,
                      color: Colors.amber.shade900,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),

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
                        if (section.bankName != null && section.bankName!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.account_balance, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Bank: ${section.bankName}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                              ),
                            ],
                          ),
                        ],
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

                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'open') {
                        _openBudgetDetails(section);
                      } else if (val == 'add') {
                        _showCompanyBudgetAdjustDialog(section, isAdd: true);
                      } else if (val == 'reduce') {
                        _showCompanyBudgetAdjustDialog(section, isAdd: false);
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
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Add Money'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reduce',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Reduce Money'),
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
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons: + Add Money, - Reduce Money, Open Details
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCompanyBudgetAdjustDialog(section, isAdd: true),
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
                      onPressed: () => _showCompanyBudgetAdjustDialog(section, isAdd: false),
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
                    onPressed: () => _openBudgetDetails(section),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Details', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================
  // --- TAB 3: CAPITAL BUDGET & BANK ACCOUNTS ---
  // ========================================================

  Widget _buildCapitalBudgetTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
        await _banksFuture;
      },
      child: FutureBuilder<List<CapitalBank>>(
        future: _banksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error loading capital banks: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                ],
              ),
            );
          }

          final banks = snapshot.data ?? [];
          final totalCapital = banks.fold<double>(0.0, (sum, b) => sum + b.balance);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Capital Summary Banner
              Card(
                elevation: 0,
                color: const Color(0xFF0A2540),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Available Capital',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${banks.length} ${banks.length == 1 ? 'Bank' : 'Banks'}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(totalCapital),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Central capital reserve for site budgets & company operations',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _showAddEditBankDialog(),
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('+ Add New Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              // View all transactions across all banks
                              _showAllCapitalAuditHistoryModal();
                            },
                            icon: const Icon(Icons.receipt_long, size: 15),
                            label: const Text('All Capital History', style: TextStyle(fontSize: 11)),
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
                    'Capital Bank Accounts',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tap card actions to deposit/reduce',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (banks.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No Capital Banks Added Yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your bank accounts to manage company capital funds and auto-deduct budget allocations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditBankDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A2540),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add First Bank'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...banks.map((bank) => _buildBankCard(bank)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBankCard(CapitalBank bank) {
    final isNegative = bank.balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0A2540),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.bankName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                      if (bank.accountNumber != null && bank.accountNumber!.isNotEmpty)
                        Text(
                          'Acc: ${bank.accountNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], letterSpacing: 0.3),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditBankDialog(bank);
                    } else if (val == 'history') {
                      _showBankTransactionsHistoryDialog(bank);
                    } else if (val == 'delete') {
                      _confirmDeleteBank(bank);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Bank Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, size: 16),
                          SizedBox(width: 8),
                          Text('Audit Log / History'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Delete Bank', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Balance Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Capital Balance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(bank.balance),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isNegative ? Colors.red : const Color(0xFF137333),
                      ),
                    ),
                  ],
                ),
                if (bank.notes != null && bank.notes!.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        bank.notes!,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons: + Add Money, - Reduce Money, History
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showBankAddReduceMoneyDialog(bank, isAdd: true),
                    icon: const Icon(Icons.arrow_downward, size: 15),
                    label: const Text('+ Add Money', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    onPressed: () => _showBankAddReduceMoneyDialog(bank, isAdd: false),
                    icon: const Icon(Icons.arrow_upward, size: 15),
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
                  onPressed: () => _showBankTransactionsHistoryDialog(bank),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('History', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCapitalAuditHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Complete Capital Transactions Audit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chronological audit trail of all capital deposits, withdrawals, and budget allocations',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              Expanded(
                child: FutureBuilder<List<CapitalBankTransaction>>(
                  future: _capitalBudgetService.getTransactions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('No transactions found'));
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final tx = list[i];
                        final isCredit = tx.isCredit;

                        IconData icon;
                        Color iconColor;

                        if (tx.transactionType == 'deposit') {
                          icon = Icons.add_circle_outline;
                          iconColor = Colors.green;
                        } else if (tx.transactionType == 'withdrawal') {
                          icon = Icons.remove_circle_outline;
                          iconColor = Colors.orange;
                        } else if (tx.transactionType == 'site_allocation') {
                          icon = Icons.location_city_rounded;
                          iconColor = Colors.blue;
                        } else {
                          icon = Icons.folder_special_rounded;
                          iconColor = Colors.purple;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tx.referenceTitle ?? tx.transactionType,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${isCredit ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isCredit ? Colors.green[800] : Colors.red[800],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Bank: ${tx.bankName} • ${dateFormat.format(tx.date)} • Bal: ${currencyFormat.format(tx.balanceAfter)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        );
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
}
