import 'package:flutter/material.dart';

class ReminderModel {
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final String category; // 'Visa', 'Passport', 'CPR', 'Contract', 'Payment', 'Meeting', 'Task', 'General'
  final String priority; // 'Low', 'Medium', 'High', 'Urgent'
  final String status; // 'Pending', 'Completed', 'Cancelled'
  final String? employeeId;
  final String? employeeName;
  final bool isForSelf;
  final String targetRole;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.category = 'General',
    this.priority = 'Medium',
    this.status = 'Pending',
    this.employeeId,
    this.employeeName,
    this.isForSelf = false,
    this.targetRole = 'Super Admin',
    this.createdBy,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPending => status.toLowerCase() == 'pending';

  bool get isOverdue {
    if (!isPending) return false;
    return dueDate.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (!isPending) return false;
    final now = DateTime.now();
    return dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
  }

  bool get isDueSoon {
    if (!isPending || isOverdue) return false;
    final diff = dueDate.difference(DateTime.now()).inDays;
    return diff <= 7;
  }

  String get remainingText {
    if (isCompleted) return 'Completed';
    final now = DateTime.now();
    if (isOverdue) {
      final diff = now.difference(dueDate);
      if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? "s" : ""} overdue';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hr${diff.inHours > 1 ? "s" : ""} overdue';
      } else {
        return 'Just overdue';
      }
    } else if (isDueToday) {
      final diff = dueDate.difference(now);
      if (diff.inHours > 0) {
        return 'Today (in ${diff.inHours}h)';
      }
      return 'Today';
    } else {
      final diff = dueDate.difference(now);
      if (diff.inDays == 1) {
        return 'Tomorrow';
      } else if (diff.inDays < 30) {
        return 'In ${diff.inDays} days';
      } else {
        final months = (diff.inDays / 30).floor();
        return 'In $months month${months > 1 ? "s" : ""}';
      }
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'visa':
        return Icons.airplane_ticket_rounded;
      case 'passport':
        return Icons.menu_book_rounded;
      case 'cpr':
      case 'id':
      case 'cpr / id':
        return Icons.badge_rounded;
      case 'contract':
        return Icons.description_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'meeting':
        return Icons.calendar_month_rounded;
      case 'task':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'visa':
        return const Color(0xFF0284C7); // Sky Blue
      case 'passport':
        return const Color(0xFF7C3AED); // Purple
      case 'cpr':
      case 'id':
      case 'cpr / id':
        return const Color(0xFF059669); // Emerald Green
      case 'contract':
        return const Color(0xFFD97706); // Amber
      case 'payment':
        return const Color(0xFF16A34A); // Green
      case 'meeting':
        return const Color(0xFFEA580C); // Orange
      case 'task':
        return const Color(0xFF2563EB); // Blue
      default:
        return const Color(0xFF4B5563); // Gray
    }
  }

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFDC2626); // Red
      case 'high':
        return const Color(0xFFEA580C); // Orange
      case 'medium':
        return const Color(0xFF0284C7); // Sky Blue
      case 'low':
        return const Color(0xFF10B981); // Emerald
      default:
        return const Color(0xFF6B7280);
    }
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Pending',
      employeeId: json['employee_id']?.toString(),
      employeeName: json['employee_name']?.toString(),
      isForSelf: json['is_for_self'] == true,
      targetRole: json['target_role'] ?? 'Super Admin',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'category': category,
      'priority': priority,
      'status': status,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'is_for_self': isForSelf,
      'target_role': targetRole,
      'created_by': createdBy,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? category,
    String? priority,
    String? status,
    String? employeeId,
    String? employeeName,
    bool? isForSelf,
    String? targetRole,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      isForSelf: isForSelf ?? this.isForSelf,
      targetRole: targetRole ?? this.targetRole,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
