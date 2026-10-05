import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_budget_transaction_model.dart';
import '../models/site_model.dart';

class SiteBudgetService {
  static final SiteBudgetService _instance = SiteBudgetService._internal();
  factory SiteBudgetService() => _instance;
  SiteBudgetService._internal();

  final _supabase = Supabase.instance.client;

  /// Fetch all sites with their latest assigned budget and financials
  Future<List<Site>> getSitesWithBudgets() async {
    final response = await _supabase
        .from('sites')
        .select('*')
        .order('created_at', ascending: false);

    final list = (response as List).map((json) => Site.fromJson(json)).toList();
    
    // Also load spent for each site from site_summary or cost tables
    final List<Site> enriched = [];
    for (final s in list) {
      try {
        final summaryRes = await _supabase
            .from('site_summary')
            .select('received_amount, cash_expenses')
            .eq('site_id', s.id);

        double totalSpent = 0.0;
        double totalReceived = 0.0;
        for (final row in (summaryRes as List)) {
          totalSpent += (row['cash_expenses'] as num?)?.toDouble() ?? 0.0;
          totalReceived += (row['received_amount'] as num?)?.toDouble() ?? 0.0;
        }

        enriched.add(Site(
          id: s.id,
          name: s.name,
          code: s.code,
          clientName: s.clientName,
          location: s.location,
          startDate: s.startDate,
          status: s.status,
          assignedBudget: s.assignedBudget,
          spent: totalSpent,
          receivedSummary: totalReceived,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
        ));
      } catch (_) {
        enriched.add(s);
      }
    }

    return enriched;
  }

  /// Fetch transactions for a specific site or for all sites
  Future<List<SiteBudgetTransaction>> getTransactions({String? siteId}) async {
    var query = _supabase.from('site_budget_transactions').select('*');
    if (siteId != null && siteId.isNotEmpty) {
      query = query.eq('site_id', siteId);
    }
    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => SiteBudgetTransaction.fromJson(json))
        .toList();
  }

  /// Add money to a site's budget
  Future<void> addBudget({
    required Site site,
    required double amount,
    required String reason,
    required DateTime date,
    String? createdBy,
  }) async {
    final previousBudget = site.assignedBudget;
    final newBudget = previousBudget + amount;

    // 1. Log transaction
    await _supabase.from('site_budget_transactions').insert({
      'site_id': site.id,
      'site_name': site.name,
      'transaction_type': 'add',
      'amount': amount,
      'previous_budget': previousBudget,
      'new_budget': newBudget,
      'reason': reason,
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });

    // 2. Update site assigned_budget
    await _supabase
        .from('sites')
        .update({'assigned_budget': newBudget})
        .eq('id', site.id);
  }

  /// Reduce money from a site's budget
  Future<void> reduceBudget({
    required Site site,
    required double amount,
    required String reason,
    required DateTime date,
    String? createdBy,
  }) async {
    final previousBudget = site.assignedBudget;
    final newBudget = (previousBudget - amount).clamp(0.0, double.infinity);

    // 1. Log transaction
    await _supabase.from('site_budget_transactions').insert({
      'site_id': site.id,
      'site_name': site.name,
      'transaction_type': 'reduce',
      'amount': amount,
      'previous_budget': previousBudget,
      'new_budget': newBudget,
      'reason': reason,
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });

    // 2. Update site assigned_budget
    await _supabase
        .from('sites')
        .update({'assigned_budget': newBudget})
        .eq('id', site.id);
  }

  /// Set or Re-assign direct budget amount
  Future<void> setBudget({
    required Site site,
    required double newBudget,
    required String reason,
    required DateTime date,
    String? createdBy,
  }) async {
    final previousBudget = site.assignedBudget;
    final diff = newBudget - previousBudget;
    final transType = diff >= 0 ? 'set_increase' : 'set_decrease';

    // 1. Log transaction
    await _supabase.from('site_budget_transactions').insert({
      'site_id': site.id,
      'site_name': site.name,
      'transaction_type': transType,
      'amount': diff.abs(),
      'previous_budget': previousBudget,
      'new_budget': newBudget,
      'reason': reason,
      'date': date.toIso8601String().split('T').first,
      'created_by': createdBy ?? 'Admin',
    });

    // 2. Update site assigned_budget
    await _supabase
        .from('sites')
        .update({'assigned_budget': newBudget})
        .eq('id', site.id);
  }
}
