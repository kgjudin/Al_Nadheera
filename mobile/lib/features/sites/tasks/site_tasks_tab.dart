import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/task_model.dart';
import '../../../models/employee_model.dart';

class SiteTasksTab extends StatefulWidget {
  final String siteId;
  const SiteTasksTab({super.key, required this.siteId});

  @override
  State<SiteTasksTab> createState() => _SiteTasksTabState();
}

class _SiteTasksTabState extends State<SiteTasksTab> {
  final ApiService _apiService = ApiService();
  late Future<List<TaskModel>> _tasksFuture;
  List<Employee> _employees = [];
  String _selectedFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> taskStatusOptions = [
    'Pending',
    'Ongoing',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadEmployees();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadTasks() {
    setState(() {
      _tasksFuture = _apiService.getTasks(widget.siteId).then(
          (data) => data.map((json) => TaskModel.fromJson(json)).toList());
    });
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await _apiService.getEmployees();
      if (mounted) {
        setState(() {
          _employees = list.map((json) => Employee.fromJson(json)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _updateTaskStatus(TaskModel task, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _apiService.updateTask(task.id, {
        'status': newStatus,
      });
      _loadTasks();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Task status changed to $newStatus'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _showAddEditTaskDialog([TaskModel? existingTask]) {
    final titleCtrl = TextEditingController(text: existingTask?.title ?? '');
    final descCtrl = TextEditingController(text: existingTask?.description ?? '');
    DateTime? dueDate = existingTask?.dueDate ?? DateTime.now().add(const Duration(days: 3));
    DateTime? startDate = existingTask?.startDate ?? DateTime.now();
    String status = _normalizeStatus(existingTask?.status ?? 'Pending');
    String? assignedEmpId = existingTask?.assignedEmployeeId;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existingTask == null ? 'Add New Task' : 'Edit Task', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Task Title *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Status Selector (Pending, Ongoing, Completed)
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                        items: taskStatusOptions.map((s) {
                          return DropdownMenuItem<String>(
                            value: s,
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 10, color: _getStatusColor(s)),
                                const SizedBox(width: 8),
                                Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Assigned Employee Selector
                      DropdownButtonFormField<String?>(
                        initialValue: assignedEmpId,
                        decoration: const InputDecoration(labelText: 'Assign Employee (Optional)', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned / General Task'),
                          ),
                          ..._employees.map((e) => DropdownMenuItem<String?>(
                                value: e.id,
                                child: Text(e.name),
                              )),
                        ],
                        onChanged: (val) => setDialogState(() => assignedEmpId = val),
                      ),
                      const SizedBox(height: 14),

                      // Due Date Picker
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dueDate == null ? 'Select Due Date' : 'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate!)}'),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          final data = {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'start_date': startDate.toIso8601String().split('T').first,
                            'due_date': dueDate?.toIso8601String().split('T').first,
                            'status': status,
                            'assigned_employee_id': assignedEmpId,
                          };

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            if (existingTask == null) {
                              await _apiService.createTask(widget.siteId, data);
                              messenger.showSnackBar(const SnackBar(content: Text('Task added successfully!')));
                            } else {
                              await _apiService.updateTask(existingTask.id, data);
                              messenger.showSnackBar(const SnackBar(content: Text('Task updated successfully!')));
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _loadTasks();
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2540),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existingTask == null ? 'Add Task' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTask(TaskModel task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete task "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await _apiService.deleteTask(task.id);
                _loadTasks();
                messenger.showSnackBar(const SnackBar(content: Text('Task deleted successfully')));
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

  static String _normalizeStatus(String status) {
    if (status.toLowerCase().contains('progress') || status.toLowerCase() == 'ongoing') {
      return 'Ongoing';
    }
    if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'done') {
      return 'Completed';
    }
    return 'Pending';
  }

  static Color _getStatusColor(String status) {
    final norm = _normalizeStatus(status);
    if (norm == 'Ongoing') {
      return const Color(0xFF0B5ED7);
    } else if (norm == 'Completed') {
      return const Color(0xFF137333);
    }
    return const Color(0xFFC2410C); // Pending
  }

  static Color _getStatusBg(String status) {
    final norm = _normalizeStatus(status);
    if (norm == 'Ongoing') {
      return const Color(0xFFE8F1FF);
    } else if (norm == 'Completed') {
      return const Color(0xFFE6F4EA);
    }
    return const Color(0xFFFFF7ED); // Pending
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error loading tasks: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadTasks, child: const Text('Retry')),
                ],
              ),
            );
          }

          final allTasks = snapshot.data ?? [];
          final query = _searchCtrl.text.trim().toLowerCase();

          // Filtering
          final filteredTasks = allTasks.where((task) {
            final norm = _normalizeStatus(task.status);
            if (_selectedFilter != 'All' && norm != _selectedFilter) {
              return false;
            }
            if (query.isNotEmpty) {
              final tMatch = task.title.toLowerCase().contains(query);
              final dMatch = (task.description ?? '').toLowerCase().contains(query);
              final aMatch = (task.assignedEmployeeName ?? '').toLowerCase().contains(query);
              if (!tMatch && !dMatch && !aMatch) return false;
            }
            return true;
          }).toList();

          final pendingCount = allTasks.where((t) => _normalizeStatus(t.status) == 'Pending').length;
          final ongoingCount = allTasks.where((t) => _normalizeStatus(t.status) == 'Ongoing').length;
          final completedCount = allTasks.where((t) => _normalizeStatus(t.status) == 'Completed').length;

          return RefreshIndicator(
            onRefresh: () async {
              _loadTasks();
              await _tasksFuture;
            },
            child: ListView(
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
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search tasks, assignees...',
                      border: InputBorder.none,
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // FILTER PILLS (All, Pending, Ongoing, Completed)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill('All (${allTasks.length})', _selectedFilter == 'All', () => setState(() => _selectedFilter = 'All')),
                      const SizedBox(width: 8),
                      _buildFilterPill('Pending ($pendingCount)', _selectedFilter == 'Pending', () => setState(() => _selectedFilter = 'Pending')),
                      const SizedBox(width: 8),
                      _buildFilterPill('Ongoing ($ongoingCount)', _selectedFilter == 'Ongoing', () => setState(() => _selectedFilter = 'Ongoing')),
                      const SizedBox(width: 8),
                      _buildFilterPill('Completed ($completedCount)', _selectedFilter == 'Completed', () => setState(() => _selectedFilter = 'Completed')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filteredTasks.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 54, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            allTasks.isEmpty ? 'No tasks added yet for this site' : 'No tasks match "$_selectedFilter"',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "+ Add Task" button below to create one.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredTasks.map((task) => _buildTaskCard(task, dateFormat)),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditTaskDialog(),
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

  Widget _buildTaskCard(TaskModel task, DateFormat dateFormat) {
    final currentNormStatus = _normalizeStatus(task.status);
    final statusColor = _getStatusColor(currentNormStatus);
    final statusBg = _getStatusBg(currentNormStatus);

    final assigneeName = task.assignedEmployeeName ?? 'Unassigned';
    final assigneeAvatar = assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : 'U';
    final dueDateStr = task.dueDate != null ? dateFormat.format(task.dueDate!) : 'Ongoing';

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
          // Header Row: Category / Priority & Interactive Status Dropdown Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('SITE TASK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Normal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                ],
              ),

              // Interactive Status Badge & Picker
              PopupMenuButton<String>(
                tooltip: 'Change Task Status',
                onSelected: (newStatus) {
                  if (newStatus != currentNormStatus) {
                    _updateTaskStatus(task, newStatus);
                  }
                },
                itemBuilder: (context) => taskStatusOptions.map((opt) {
                  final isSelected = opt == currentNormStatus;
                  return PopupMenuItem<String>(
                    value: opt,
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: _getStatusColor(opt),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          opt,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: _getStatusColor(opt),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        currentNormStatus,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Description
          Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(task.description!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Footer: Assignee, Due Date, and Actions Menu (Edit/Delete)
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: task.assignedEmployeeName != null ? const Color(0xFFE6F4EA) : Colors.grey.shade200,
                child: Text(
                  assigneeAvatar,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: task.assignedEmployeeName != null ? const Color(0xFF137333) : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  assigneeName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0A2540)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 12, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    'Due: $dueDateStr',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showAddEditTaskDialog(task);
                  } else if (val == 'delete') {
                    _confirmDeleteTask(task);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Task'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Delete Task', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
