import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_model.dart';

class ReminderService extends ChangeNotifier {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final _supabase = Supabase.instance.client;

  /// Fetch all reminders with optional filters
  Future<List<ReminderModel>> getReminders({
    String? status,
    String? category,
    bool? isForSelf,
    String? employeeId,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from('reminders').select('*');

      if (status != null && status != 'All') {
        if (status == 'Active') {
          query = query.neq('status', 'Completed');
        } else {
          query = query.eq('status', status);
        }
      }

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }

      if (isForSelf != null) {
        query = query.eq('is_for_self', isForSelf);
      }

      if (employeeId != null && employeeId.isNotEmpty) {
        query = query.eq('employee_id', employeeId);
      }

      final res = await query.order('due_date', ascending: true);
      List<ReminderModel> reminders =
          (res as List).map((j) => ReminderModel.fromJson(j)).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        reminders = reminders.where((r) {
          final titleMatch = r.title.toLowerCase().contains(q);
          final descMatch = r.description?.toLowerCase().contains(q) ?? false;
          final empMatch = r.employeeName?.toLowerCase().contains(q) ?? false;
          final catMatch = r.category.toLowerCase().contains(q);
          return titleMatch || descMatch || empMatch || catMatch;
        }).toList();
      }

      return reminders;
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
      return [];
    }
  }

  /// Fetch pending reminders for notifications and dashboard widget
  Future<List<ReminderModel>> getPendingReminders() async {
    try {
      final res = await _supabase
          .from('reminders')
          .select('*')
          .neq('status', 'Completed')
          .order('due_date', ascending: true);

      return (res as List).map((j) => ReminderModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error fetching pending reminders: $e');
      return [];
    }
  }

  /// Create a new reminder
  Future<ReminderModel?> createReminder(ReminderModel reminder) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = reminder.toJson();
      if (user != null) {
        payload['created_by'] = user.id;
      }

      final res = await _supabase
          .from('reminders')
          .insert(payload)
          .select()
          .single();

      notifyListeners();
      return ReminderModel.fromJson(res);
    } catch (e) {
      debugPrint('Error creating reminder: $e');
      rethrow;
    }
  }

  /// Update an existing reminder
  Future<ReminderModel?> updateReminder(ReminderModel reminder) async {
    try {
      final payload = reminder.toJson();
      final res = await _supabase
          .from('reminders')
          .update(payload)
          .eq('id', reminder.id)
          .select()
          .single();

      notifyListeners();
      return ReminderModel.fromJson(res);
    } catch (e) {
      debugPrint('Error updating reminder: $e');
      rethrow;
    }
  }

  /// Toggle or update reminder status ('Pending', 'Completed', etc.)
  Future<void> toggleReminderStatus(String id, String newStatus) async {
    try {
      await _supabase.from('reminders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling reminder status: $e');
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    try {
      await _supabase.from('reminders').delete().eq('id', id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Get quick summary counts for badges and indicators
  Future<Map<String, int>> getReminderCounts() async {
    try {
      final res = await _supabase.from('reminders').select('id, due_date, status');
      final list = res as List;

      int total = list.length;
      int pending = 0;
      int overdue = 0;
      int dueSoon = 0;
      int completed = 0;

      final now = DateTime.now();

      for (final item in list) {
        final status = (item['status'] ?? 'Pending').toString();
        if (status.toLowerCase() == 'completed') {
          completed++;
          continue;
        }

        pending++;
        final dueDateStr = item['due_date']?.toString();
        if (dueDateStr != null) {
          final due = DateTime.tryParse(dueDateStr);
          if (due != null) {
            if (due.isBefore(now)) {
              overdue++;
            } else if (due.difference(now).inDays <= 7) {
              dueSoon++;
            }
          }
        }
      }

      return {
        'total': total,
        'pending': pending,
        'overdue': overdue,
        'dueSoon': dueSoon,
        'completed': completed,
      };
    } catch (e) {
      debugPrint('Error calculating reminder counts: $e');
      return {
        'total': 0,
        'pending': 0,
        'overdue': 0,
        'dueSoon': 0,
        'completed': 0,
      };
    }
  }
}
