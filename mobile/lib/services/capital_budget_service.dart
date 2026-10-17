import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capital_bank_model.dart';

class CapitalBudgetService {
  static final CapitalBudgetService _instance = CapitalBudgetService._internal();
  factory CapitalBudgetService() => _instance;
  CapitalBudgetService._internal();

  final _supabase = Supabase.instance.client;

  /// Fetch all capital banks
  Future<List<CapitalBank>> getBanks() async {
    final res = await _supabase
        .from('capital_banks')
        .select('*')
        .order('bank_name', ascending: true);

    return (res as List).map((j) => CapitalBank.fromJson(j)).toList();
  }

  /// Fetch single bank by ID
  Future<CapitalBank?> getBankById(String id) async {
    final res = await _supabase
        .from('capital_banks')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return CapitalBank.fromJson(res);
  }

  /// Create a new capital bank
  Future<CapitalBank> createBank({
    required String bankName,
    String? accountNumber,
    required double initialBalance,
    String? notes,
    DateTime? date,
    String? createdBy,
  }) async {
    final insertData = {
      'bank_name': bankName.trim(),
      'account_number': accountNumber?.trim().isEmpty ?? true ? null : accountNumber?.trim(),
      'balance': initialBalance,
      'notes': notes?.trim().isEmpty ?? true ? null : notes?.trim(),
    };

    final res = await _supabase
        .from('capital_banks')
        .insert(insertData)
        .select()
        .single();

    final bank = CapitalBank.fromJson(res);

    // If initial balance > 0, log an initial deposit transaction
    if (initialBalance > 0) {
      await _supabase.from('capital_bank_transactions').insert({
        'bank_id': bank.id,
        'bank_name': bank.bankName,
        'transaction_type': 'deposit',
        'amount': initialBalance,
        'balance_after': initialBalance,
        'reference_title': 'Initial Capital Deposit',
        'notes': notes?.trim(),
        'date': (date ?? DateTime.now()).toIso8601String().split('T').first,
        'created_by': createdBy ?? 'Admin',
      });
    }

    return bank;
  }

  /// Update bank details
  Future<void> updateBank({
    required String id,
    required String bankName,
    String? accountNumber,
    String? notes,
  }) async {
    await _supabase.from('capital_banks').update({
      'bank_name': bankName.trim(),
      'account_number': accountNumber?.trim().isEmpty ?? true ? null : accountNumber?.trim(),
      'notes': notes?.trim().isEmpty ?? true ? null : notes?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // Also update cached bank_name on transactions
    await _supabase
        .from('capital_bank_transactions')
        .update({'bank_name': bankName.trim()})
        .eq('bank_id', id);
  }

  /// Delete bank
  Future<void> deleteBank(String id) async {
    await _supabase.from('capital_banks').delete().eq('id', id);
  }

  /// Add Money to Bank (Deposit / Capital Infusion)
  Future<void> addMoney({
    required CapitalBank bank,
    required double amount,
    required String reason,
    required DateTime date,
    String? createdBy,
  }) async {
    final currentBank = await getBankById(bank.id) ?? bank;
    final newBalance = currentBank.balance + amount;

    // 1. Update bank balance
    await _supabase.from('capital_banks').update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bank.id);

    // 2. Log transaction
    await _supabase.from('capital_bank_transactions').insert({
      'bank_id': bank.id,
      'bank_name': bank.bankName,
      'transaction_type': 'deposit',
      'amount': amount,
      'balance_after': newBalance,
      'reference_title': reason.trim(),
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });
  }

  /// Reduce Money from Bank (Withdrawal / Capital Drawdown)
  Future<void> reduceMoney({
    required CapitalBank bank,
    required double amount,
    required String reason,
    required DateTime date,
    String? createdBy,
  }) async {
    final currentBank = await getBankById(bank.id) ?? bank;
    final newBalance = currentBank.balance - amount;

    // 1. Update bank balance
    await _supabase.from('capital_banks').update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bank.id);

    // 2. Log transaction
    await _supabase.from('capital_bank_transactions').insert({
      'bank_id': bank.id,
      'bank_name': bank.bankName,
      'transaction_type': 'withdrawal',
      'amount': amount,
      'balance_after': newBalance,
      'reference_title': reason.trim(),
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });
  }

  /// Deduct money from Capital Bank for Site Budget allocation
  Future<void> deductForSiteBudget({
    required String bankId,
    required String bankName,
    required String siteId,
    required String siteName,
    required double amount,
    required DateTime date,
    String? reason,
    String? createdBy,
  }) async {
    final bank = await getBankById(bankId);
    if (bank == null) return;

    final newBalance = bank.balance - amount;

    // 1. Update bank balance
    await _supabase.from('capital_banks').update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bankId);

    // 2. Record transaction
    await _supabase.from('capital_bank_transactions').insert({
      'bank_id': bankId,
      'bank_name': bank.bankName,
      'transaction_type': 'site_allocation',
      'amount': amount,
      'balance_after': newBalance,
      'reference_title': 'Transferred to Site: $siteName',
      'site_id': siteId,
      'notes': reason?.trim(),
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });
  }

  /// Deduct money from Capital Bank for Company Budget File creation / income addition
  Future<void> deductForCompanyBudget({
    required String bankId,
    required String bankName,
    required String incomeSectionId,
    required String budgetTitle,
    required double amount,
    required DateTime date,
    String? notes,
    String? createdBy,
  }) async {
    final bank = await getBankById(bankId);
    if (bank == null) return;

    final newBalance = bank.balance - amount;

    // 1. Update bank balance
    await _supabase.from('capital_banks').update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bankId);

    // 2. Record transaction
    await _supabase.from('capital_bank_transactions').insert({
      'bank_id': bankId,
      'bank_name': bank.bankName,
      'transaction_type': 'company_allocation',
      'amount': amount,
      'balance_after': newBalance,
      'reference_title': 'Allocated to Company Budget: $budgetTitle',
      'income_section_id': incomeSectionId,
      'notes': notes?.trim(),
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });
  }

  /// Return / credit money from Company Budget back into a Capital Bank
  Future<void> returnFromCompanyBudget({
    required String bankId,
    required String bankName,
    required String incomeSectionId,
    required String budgetTitle,
    required double amount,
    required DateTime date,
    String? notes,
    String? createdBy,
  }) async {
    final bank = await getBankById(bankId);
    if (bank == null) return;

    final newBalance = bank.balance + amount;

    // 1. Update bank balance
    await _supabase.from('capital_banks').update({
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bankId);

    // 2. Record transaction
    await _supabase.from('capital_bank_transactions').insert({
      'bank_id': bankId,
      'bank_name': bank.bankName,
      'transaction_type': 'company_return',
      'amount': amount,
      'balance_after': newBalance,
      'reference_title': 'Returned from Company Budget: $budgetTitle',
      'income_section_id': incomeSectionId,
      'notes': notes?.trim(),
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });
  }

  /// Fetch transactions for a specific bank or all banks
  Future<List<CapitalBankTransaction>> getTransactions({String? bankId}) async {
    var query = _supabase.from('capital_bank_transactions').select('*');
    if (bankId != null && bankId.isNotEmpty) {
      query = query.eq('bank_id', bankId);
    }
    final res = await query.order('created_at', ascending: false);

    return (res as List).map((j) => CapitalBankTransaction.fromJson(j)).toList();
  }
}
