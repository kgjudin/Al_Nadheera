import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/reminder_model.dart';
import '../../models/employee_model.dart';
import '../../services/reminder_service.dart';
import '../../services/permission_service.dart';

class RemindersScreen extends StatefulWidget {
  final bool showAppBar;
  const RemindersScreen({super.key, this.showAppBar = true});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderService _reminderService = ReminderService();
  final PermissionService _permissionService = PermissionService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ReminderModel> _reminders = [];
  Map<String, int> _counts = {
    'total': 0,
    'pending': 0,
    'overdue': 0,
    'dueSoon': 0,
    'completed': 0,
  };
  bool _isLoading = true;

  // Filter states
  String _selectedStatus = 'All'; // 'All', 'Pending', 'Overdue', 'Due Soon', 'Completed'
  String _selectedCategory = 'All'; // 'All', 'Visa', 'Passport', 'CPR', 'Contract', etc.
  String _selectedAudience = 'All'; // 'All', 'Self', 'Employees'

  final List<String> _categories = [
    'All',
    'Visa',
    'Passport',
    'CPR',
    'Contract',
    'Payment',
    'Meeting',
    'Task',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final counts = await _reminderService.getReminderCounts();
      final reminders = await _reminderService.getReminders(
        searchQuery: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _counts = counts;
          _reminders = reminders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ReminderModel> get _filteredReminders {
    return _reminders.where((r) {
      // 1. Status Filter
      if (_selectedStatus == 'Pending') {
        if (r.isCompleted) return false;
      } else if (_selectedStatus == 'Overdue') {
        if (!r.isOverdue) return false;
      } else if (_selectedStatus == 'Due Soon') {
        if (!r.isDueSoon) return false;
      } else if (_selectedStatus == 'Completed') {
        if (!r.isCompleted) return false;
      }

      // 2. Audience Filter
      if (_selectedAudience == 'Self') {
        if (!r.isForSelf) return false;
      } else if (_selectedAudience == 'Employees') {
        if (r.isForSelf) return false;
      }

      // 3. Category Filter
      if (_selectedCategory != 'All') {
        if (r.category.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _toggleStatus(ReminderModel reminder) async {
    final newStatus = reminder.isCompleted ? 'Pending' : 'Completed';
    try {
      await _reminderService.toggleReminderStatus(reminder.id, newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Completed'
                  ? 'Marked as completed: ${reminder.title}'
                  : 'Reopened reminder: ${reminder.title}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newStatus == 'Completed' ? Colors.green[700] : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder(ReminderModel reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _reminderService.deleteReminder(reminder.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _openAddEditDialog([ReminderModel? reminder]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditReminderSheet(
        reminder: reminder,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionService.isSuperAdmin) {
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Reminders & Renewals'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              )
            : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 56, color: Colors.red.shade400),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only Super Admin accounts have permission to access and manage renewals and reminders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filteredReminders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: const Row(
                children: [
                  Icon(Icons.notification_important_rounded, color: Color(0xFF0F4C81), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Reminders & Renewals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F2537),
                    ),
                  ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F2537)),
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F4C81)),
                  tooltip: 'Refresh',
                  onPressed: _loadData,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Add Reminder',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openAddEditDialog(),
                  ),
                ),
              ],
            )
          : null,
      floatingActionButton: !widget.showAppBar
          ? FloatingActionButton.extended(
              onPressed: () => _openAddEditDialog(),
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // 1. Stats Counter Cards
                  _buildStatsRow(),

                  const SizedBox(height: 16),

                  // 2. Search & Audience Toggle
                  _buildSearchAndAudienceBar(),

                  const SizedBox(height: 12),

                  // 3. Status Filters (All, Pending, Overdue, Due Soon, Completed)
                  _buildStatusFilterRow(),

                  const SizedBox(height: 10),

                  // 4. Category Filter Chips (Visa, Passport, CPR, Contract, etc.)
                  _buildCategoryChips(),

                  const SizedBox(height: 16),

                  // 5. Section Header & List Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reminders (${filtered.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2537),
                        ),
                      ),
                      if (filtered.isNotEmpty)
                        Text(
                          'Sorted by Due Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 6. Reminder Cards List
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map((r) => _buildReminderCard(r)),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cards = [
          _buildStatCard(
            title: 'Total',
            count: _counts['total'] ?? 0,
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFF0F4C81),
            bgColor: const Color(0xFFEFF6FF),
            isSelected: _selectedStatus == 'All',
            onTap: () => setState(() => _selectedStatus = 'All'),
          ),
          _buildStatCard(
            title: 'Pending',
            count: _counts['pending'] ?? 0,
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
            isSelected: _selectedStatus == 'Pending',
            onTap: () => setState(() => _selectedStatus = 'Pending'),
          ),
          _buildStatCard(
            title: 'Overdue',
            count: _counts['overdue'] ?? 0,
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEE2E2),
            isSelected: _selectedStatus == 'Overdue',
            onTap: () => setState(() => _selectedStatus = 'Overdue'),
          ),
          _buildStatCard(
            title: 'Due Soon (7d)',
            count: _counts['dueSoon'] ?? 0,
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
            isSelected: _selectedStatus == 'Due Soon',
            onTap: () => setState(() => _selectedStatus = 'Due Soon'),
          ),
        ];

        if (isWide) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        } else {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
              const SizedBox(width: 8),
              Expanded(child: cards[2]),
              const SizedBox(width: 8),
              Expanded(child: cards[3]),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndAudienceBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search title, employee name, category...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0F4C81)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Target:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    _buildAudienceChip('All', 'All Reminders'),
                    const SizedBox(width: 6),
                    _buildAudienceChip('Self', 'For Myself (Admin)'),
                    const SizedBox(width: 6),
                    _buildAudienceChip('Employees', 'Employee-wise'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String key, String label) {
    final isSelected = _selectedAudience == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAudience = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F4C81) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    final statusList = ['All', 'Pending', 'Overdue', 'Due Soon', 'Completed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusList.map((s) {
          final isSelected = _selectedStatus == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedStatus = s);
              },
              selectedColor: const Color(0xFF0F4C81),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F4C81) : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(c),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedCategory = val ? c : 'All');
              },
              selectedColor: const Color(0xFF0F4C81).withValues(alpha: 0.12),
              checkmarkColor: const Color(0xFF0F4C81),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0F4C81) : const Color(0xFF475569),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F4C81) : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReminderCard(ReminderModel r) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(r.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.isOverdue
              ? Colors.red.shade200
              : (r.isCompleted ? Colors.green.shade100 : Colors.grey.shade200),
          width: r.isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon + Title + Status Pill + Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: r.categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(r.categoryIcon, color: r.categoryColor, size: 20),
                ),
                const SizedBox(width: 10),
                // Title & Remaining / Due Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                                color: r.isCompleted ? Colors.grey : const Color(0xFF0F2537),
                              ),
                            ),
                          ),
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: r.priorityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          // Status Pill (Overdue / Due Soon / Completed)
                          _buildStatusPill(r),
                        ],
                      ),
                    ],
                  ),
                ),
                // Overflow Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openAddEditDialog(r);
                    } else if (val == 'delete') {
                      _deleteReminder(r);
                    } else if (val == 'toggle') {
                      _toggleStatus(r);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            r.isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: r.isCompleted ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(r.isCompleted ? 'Reopen' : 'Mark Complete'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F4C81)),
                          const SizedBox(width: 8),
                          Text('Edit Reminder'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (r.description != null && r.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Row: Employee / Audience Badge + Category Tag + Quick Complete
            Row(
              children: [
                // Audience / Employee Tag
                if (r.isForSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 13, color: Color(0xFF0F4C81)),
                        SizedBox(width: 4),
                        Text(
                          'For Myself (Super Admin)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F4C81),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          r.employeeName ?? 'Employee Reminder',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(width: 8),

                // Category pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.category,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ),

                const Spacer(),

                // Quick Toggle Complete Button
                InkWell(
                  onTap: () => _toggleStatus(r),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: r.isCompleted ? const Color(0xFFE6F4EA) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: r.isCompleted ? const Color(0xFF16A34A) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          r.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: r.isCompleted ? const Color(0xFF16A34A) : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          r.isCompleted ? 'Done' : 'Mark Done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: r.isCompleted ? const Color(0xFF16A34A) : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ReminderModel r) {
    if (r.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Completed',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
        ),
      );
    }

    if (r.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          r.remainingText,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
        ),
      );
    }

    if (r.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          r.remainingText,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        r.remainingText,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Reminders Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
            ),
            const SizedBox(height: 6),
            Text(
              'Set reminders for visa, passport expiry, contracts, or personal alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Reminder'),
              onPressed: () => _openAddEditDialog(),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ADD / EDIT REMINDER MODAL SHEET
// ----------------------------------------------------------------------

class _AddEditReminderSheet extends StatefulWidget {
  final ReminderModel? reminder;
  final VoidCallback onSaved;

  const _AddEditReminderSheet({
    this.reminder,
    required this.onSaved,
  });

  @override
  State<_AddEditReminderSheet> createState() => _AddEditReminderSheetState();
}

class _AddEditReminderSheetState extends State<_AddEditReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  String _selectedCategory = 'Visa';
  String _selectedPriority = 'Medium';
  bool _isForSelf = true;
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isSaving = false;

  final List<String> _presetTitles = [
    'Visa Renewal',
    'Passport Expiry',
    'CPR / Civil ID Renewal',
    'Contract Renewal',
    'Labour Card Renewal',
    'Driving License Expiry',
    'Insurance Policy Renewal',
    'Client Meeting',
    'Supplier Payment Due',
  ];

  final List<String> _categories = [
    'Visa',
    'Passport',
    'CPR',
    'Contract',
    'Payment',
    'Meeting',
    'Task',
    'General',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadEmployees();

    if (widget.reminder != null) {
      final r = widget.reminder!;
      _titleController.text = r.title;
      _descriptionController.text = r.description ?? '';
      _selectedDate = r.dueDate;
      _selectedTime = TimeOfDay(hour: r.dueDate.hour, minute: r.dueDate.minute);
      _selectedCategory = r.category;
      _selectedPriority = r.priority;
      _isForSelf = r.isForSelf;
      _selectedEmployeeId = r.employeeId;
      _selectedEmployeeName = r.employeeName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await Supabase.instance.client
          .from('employees')
          .select('id, name, role, employee_id')
          .eq('status', 'Active')
          .order('name', ascending: true);

      final list = (res as List).map((j) => Employee.fromJson(j)).toList();
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _applyPresetDateOffset(int days) {
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isForSelf && _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee for this reminder')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final reminderModel = ReminderModel(
        id: widget.reminder?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: combinedDateTime,
        category: _selectedCategory,
        priority: _selectedPriority,
        status: widget.reminder?.status ?? 'Pending',
        isForSelf: _isForSelf,
        employeeId: _isForSelf ? null : _selectedEmployeeId,
        employeeName: _isForSelf ? 'Super Admin' : _selectedEmployeeName,
        targetRole: 'Super Admin',
      );

      final service = ReminderService();
      if (widget.reminder == null) {
        await service.createReminder(reminderModel);
      } else {
        await service.updateReminder(reminderModel);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.reminder == null
                  ? 'Reminder added successfully'
                  : 'Reminder updated successfully',
            ),
            backgroundColor: const Color(0xFF0F4C81),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reminder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final formattedDate = dateFormat.format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alarm_add_rounded, color: Color(0xFF0F4C81), size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.reminder == null ? 'Add New Reminder' : 'Edit Reminder',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F2537),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Audience selector: For Me vs For Employee
                  const Text(
                    'Reminder For:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isForSelf = true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isForSelf ? const Color(0xFF0F4C81) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isForSelf ? const Color(0xFF0F4C81) : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 16,
                                  color: _isForSelf ? Colors.white : const Color(0xFF4B5563),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'For Myself (Admin)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isForSelf ? Colors.white : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isForSelf = false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isForSelf ? const Color(0xFF0F4C81) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isForSelf ? const Color(0xFF0F4C81) : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_rounded,
                                  size: 16,
                                  color: !_isForSelf ? Colors.white : const Color(0xFF4B5563),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'For Employee',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: !_isForSelf ? Colors.white : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // If For Employee: Dropdown selector
                  if (!_isForSelf) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Select Employee:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingEmployees
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedEmployeeId,
                            hint: const Text('Choose staff member...'),
                            items: _employees.map((emp) {
                              return DropdownMenuItem<String>(
                                value: emp.id,
                                child: Text('${emp.name} (${emp.role ?? "Staff"})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedEmployeeId = val;
                                final match = _employees.firstWhere((e) => e.id == val);
                                _selectedEmployeeName = match.name;
                                // Auto-fill title if empty
                                if (_titleController.text.isEmpty) {
                                  _titleController.text = '$_selectedCategory Renewal - ${match.name}';
                                }
                              });
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                  ],

                  const SizedBox(height: 16),

                  // Category Selector
                  const Text(
                    'Category / Type:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _categories.map((c) {
                      final isSelected = _selectedCategory == c;
                      return ChoiceChip(
                        label: Text(c),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedCategory = c;
                              if (_titleController.text.isEmpty ||
                                  _presetTitles.any((p) => _titleController.text.contains(p))) {
                                final empPart = (!_isForSelf && _selectedEmployeeName != null)
                                    ? ' - $_selectedEmployeeName'
                                    : '';
                                _titleController.text = '$c Renewal$empPart';
                              }
                            });
                          }
                        },
                        selectedColor: const Color(0xFF0F4C81),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF0F4C81) : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Title Field + Quick Suggestions
                  const Text(
                    'Reminder Title:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter a reminder title' : null,
                    decoration: InputDecoration(
                      hintText: 'e.g. Visa Renewal, Passport Expiry...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presetTitles.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(p, style: const TextStyle(fontSize: 11)),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onPressed: () {
                              setState(() {
                                final empPart = (!_isForSelf && _selectedEmployeeName != null)
                                    ? ' - $_selectedEmployeeName'
                                    : '';
                                _titleController.text = '$p$empPart';
                                if (p.contains('Visa')) _selectedCategory = 'Visa';
                                if (p.contains('Passport')) _selectedCategory = 'Passport';
                                if (p.contains('CPR')) _selectedCategory = 'CPR';
                                if (p.contains('Contract')) _selectedCategory = 'Contract';
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date & Time Picker
                  const Text(
                    'Due Date & Time:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Date Selector Button
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF0F4C81)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Time Selector Button
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0F4C81)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    formattedTime,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quick date presets (+7d, +15d, +30d, +60d, +6m)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Quick Presets: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        _buildPresetChip('+7 Days', 7),
                        _buildPresetChip('+15 Days', 15),
                        _buildPresetChip('+30 Days', 30),
                        _buildPresetChip('+60 Days', 60),
                        _buildPresetChip('+6 Months', 180),
                        _buildPresetChip('+1 Year', 365),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Priority Selector
                  const Text(
                    'Priority Level:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _priorities.map((p) {
                      final isSelected = _selectedPriority == p;
                      Color pColor = const Color(0xFF0F4C81);
                      if (p == 'Urgent') pColor = Colors.red;
                      if (p == 'High') pColor = Colors.orange;
                      if (p == 'Medium') pColor = Colors.blue;
                      if (p == 'Low') pColor = Colors.green;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => setState(() => _selectedPriority = p),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? pColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Description / Notes Field
                  const Text(
                    'Notes / Description (Optional):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add details, document numbers, passport or CPR numbers...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C81),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              widget.reminder == null ? 'Save Reminder' : 'Update Reminder',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int days) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10.5)),
        backgroundColor: const Color(0xFFF1F5F9),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => _applyPresetDateOffset(days),
      ),
    );
  }
}
