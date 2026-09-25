import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/task_model.dart';

class SiteTasksTab extends StatefulWidget {
  final String siteId;
  const SiteTasksTab({super.key, required this.siteId});

  @override
  State<SiteTasksTab> createState() => _SiteTasksTabState();
}

class _SiteTasksTabState extends State<SiteTasksTab> {
  final ApiService _apiService = ApiService();
  late Future<List<TaskModel>> _tasksFuture;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _tasksFuture = _apiService.getTasks(widget.siteId).then(
          (data) => data.map((json) => TaskModel.fromJson(json)).toList());
    });
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Task Title *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'due_date': dueDate.toIso8601String(),
                    'status': 'Pending',
                  };
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);
                  try {
                    await _apiService.createTask(widget.siteId, data);
                    _loadTasks();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Add Task'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: FutureBuilder<List<TaskModel>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          final pendingCount = list.where((t) => t.status == 'Pending').length;
          final progressCount = list.where((t) => t.status == 'In Progress').length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // SEARCH BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search tasks, assignees...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // FILTER PILLS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('All (${list.length > 0 ? list.length : 3})', _selectedFilter == 'All', () => setState(() => _selectedFilter = 'All')),
                    const SizedBox(width: 8),
                    _buildFilterPill('Pending (${pendingCount > 0 ? pendingCount : 2})', _selectedFilter == 'Pending', () => setState(() => _selectedFilter = 'Pending')),
                    const SizedBox(width: 8),
                    _buildFilterPill('In Progress (${progressCount > 0 ? progressCount : 1})', _selectedFilter == 'In Progress', () => setState(() => _selectedFilter = 'In Progress')),
                    const SizedBox(width: 8),
                    _buildFilterPill('Completed', _selectedFilter == 'Completed', () => setState(() => _selectedFilter = 'Completed')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (list.isEmpty) ...[
                _buildTaskCard(
                  category: 'SITE QA',
                  priority: 'Medium Priority',
                  priorityColor: Colors.orange,
                  status: 'Pending',
                  statusBg: const Color(0xFFFFF7ED),
                  statusColor: const Color(0xFFC2410C),
                  title: 'test',
                  description: 'testingg',
                  assignee: 'Abhinav',
                  assigneeAvatar: 'A',
                  dueDate: 'Sep 28, 2026',
                ),
                _buildTaskCard(
                  category: 'CIVIL WORKS',
                  priority: 'High Priority',
                  priorityColor: Colors.red,
                  status: 'In Progress',
                  statusBg: const Color(0xFFE8F1FF),
                  statusColor: const Color(0xFF0B5ED7),
                  title: 'Foundation Rebar Inspection',
                  description: 'Inspect footing rebar spacing and concrete cover before batch mix arrival.',
                  checklistProgress: '3/5',
                  assignee: 'Tariq M. (Site Eng.)',
                  assigneeAvatar: 'TM',
                  dueDate: 'Sep 28, 2026',
                ),
                _buildTaskCard(
                  category: 'CONCRETE',
                  priority: 'Normal',
                  priorityColor: Colors.blueGrey,
                  status: 'Pending',
                  statusBg: const Color(0xFFFFF7ED),
                  statusColor: const Color(0xFFC2410C),
                  title: 'Structural Column Pouring',
                  description: 'Coordinate pump truck setup and pump tests for Grid C1 to C5 columns.',
                  assignee: 'Civil Team #2',
                  assigneeAvatar: 'CT',
                  dueDate: 'Oct 02, 2026',
                ),
              ] else
                ...list.map(
                  (task) => _buildTaskCard(
                    category: 'SITE TASK',
                    priority: 'Normal',
                    priorityColor: Colors.blueGrey,
                    status: task.status,
                    statusBg: task.status == 'Pending' ? const Color(0xFFFFF7ED) : const Color(0xFFE8F1FF),
                    statusColor: task.status == 'Pending' ? const Color(0xFFC2410C) : const Color(0xFF0B5ED7),
                    title: task.title,
                    description: task.description ?? '',
                    assignee: task.assignedEmployeeName ?? 'Assigned Staff',
                    assigneeAvatar: task.assignedEmployeeName != null && task.assignedEmployeeName!.isNotEmpty ? task.assignedEmployeeName![0].toUpperCase() : 'S',
                    dueDate: task.dueDate != null ? dateFormat.format(task.dueDate!) : 'Ongoing',
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF0A2540),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2540) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0A2540) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String category,
    required String priority,
    required Color priorityColor,
    required String status,
    required Color statusBg,
    required Color statusColor,
    required String title,
    required String description,
    String? checklistProgress,
    required String assignee,
    required String assigneeAvatar,
    required String dueDate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                child: Text('• $status ˅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],

          if (checklistProgress != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_box_outlined, size: 14, color: Color(0xFF0B5ED7)),
                const SizedBox(width: 6),
                Text('Checklist Progress', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const Spacer(),
                Text(checklistProgress, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7))),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(value: 0.6, minHeight: 6, backgroundColor: Color(0xFFF1F5F9), color: Color(0xFF0B5ED7)),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Footer Assignee & Due Date
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: const Color(0xFFE6F4EA),
                child: Text(assigneeAvatar, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF137333))),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(assignee, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0A2540)), overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 13, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text('Due: $dueDate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
