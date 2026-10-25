import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/task_model.dart';
import '../../../models/employee_model.dart';
import 'widgets/task_details_sheet.dart';
import '../../../services/permission_service.dart';
import '../../../core/constants/app_modules.dart';

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

  // Selection mode states
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};
  bool _isBulkActionInProgress = false;

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
      _tasksFuture = _apiService.getTasks(widget.siteId).then((data) {
        final list = data.map((json) => TaskModel.fromJson(json)).toList();
        // Remove any selected IDs that no longer exist
        final existingIds = list.map((t) => t.id).toSet();
        _selectedTaskIds.removeWhere((id) => !existingIds.contains(id));
        if (_selectedTaskIds.isEmpty && _isSelectionMode) {
          _isSelectionMode = false;
        }
        return list;
      });
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

  void _toggleSelectionMode([bool? enable]) {
    setState(() {
      _isSelectionMode = enable ?? !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAllTasks(List<TaskModel> tasks) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.addAll(tasks.map((t) => t.id));
    });
  }

  void _clearTaskSelection() {
    setState(() {
      _selectedTaskIds.clear();
    });
  }

  void _selectSingleTask(String taskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.clear();
      _selectedTaskIds.add(taskId);
    });
  }

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedTaskIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = _selectedTaskIds.length;
    setState(() => _isBulkActionInProgress = true);
    try {
      await _apiService.bulkUpdateTasks(_selectedTaskIds.toList(), {'status': newStatus});
      setState(() {
        _selectedTaskIds.clear();
        _isSelectionMode = false;
        _isBulkActionInProgress = false;
      });
      _loadTasks();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$count task${count > 1 ? 's' : ''} updated to $newStatus'),
          backgroundColor: const Color(0xFF137333),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isBulkActionInProgress = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to update tasks: $e')));
    }
  }

  void _confirmBulkDelete() {
    if (_selectedTaskIds.isEmpty) return;
    final count = _selectedTaskIds.length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Selected Tasks'),
          ],
        ),
        content: Text('Are you sure you want to delete $count selected task${count > 1 ? 's' : ''}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isBulkActionInProgress = true);
              try {
                await _apiService.bulkDeleteTasks(_selectedTaskIds.toList());
                setState(() {
                  _selectedTaskIds.clear();
                  _isSelectionMode = false;
                  _isBulkActionInProgress = false;
                });
                _loadTasks();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$count task${count > 1 ? 's' : ''} deleted successfully'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              } catch (e) {
                setState(() => _isBulkActionInProgress = false);
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete All Selected'),
          ),
        ],
      ),
    );
  }

  void _showBulkAssignDialog() {
    if (_selectedTaskIds.isEmpty) return;
    final count = _selectedTaskIds.length;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Assign $count Selected Task${count > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an employee to assign these tasks to:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_off_outlined, color: Colors.white, size: 18),
                  ),
                  title: const Text('Unassign / General Task', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _bulkAssignTasks(null, 'Unassigned');
                  },
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (context, i) {
                      final emp = _employees[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0A2540),
                          child: Text(
                            emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: emp.role != null && emp.role!.isNotEmpty ? Text(emp.role!) : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _bulkAssignTasks(emp.id, emp.name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _bulkAssignTasks(String? employeeId, String employeeName) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = _selectedTaskIds.length;
    setState(() => _isBulkActionInProgress = true);
    try {
      await _apiService.bulkUpdateTasks(
        _selectedTaskIds.toList(),
        {'assigned_employee_id': employeeId},
      );
      setState(() {
        _selectedTaskIds.clear();
        _isSelectionMode = false;
        _isBulkActionInProgress = false;
      });
      _loadTasks();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$count task${count > 1 ? 's' : ''} assigned to $employeeName'),
          backgroundColor: const Color(0xFF137333),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isBulkActionInProgress = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to assign tasks: $e')));
    }
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

  Future<void> _showMultiEmployeeSelectModal(
    BuildContext context,
    Set<String> selectedEmpIds,
  ) async {
    final searchCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = _employees.where((e) {
              if (query.isEmpty) return true;
              return e.name.toLowerCase().contains(query) ||
                  (e.role ?? '').toLowerCase().contains(query);
            }).toList();

            final allFilteredSelected = filtered.isNotEmpty &&
                filtered.every((e) => selectedEmpIds.contains(e.id));

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Employees',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (allFilteredSelected) {
                              for (final e in filtered) {
                                selectedEmpIds.remove(e.id);
                              }
                            } else {
                              for (final e in filtered) {
                                selectedEmpIds.add(e.id);
                              }
                            }
                          });
                        },
                        child: Text(allFilteredSelected ? 'Deselect All' : 'Select All'),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, size: 18, color: Colors.grey),
                        hintText: 'Search by name or role...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No employees found',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final emp = filtered[i];
                              final isSelected = selectedEmpIds.contains(emp.id);
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF0A2540),
                                  child: Text(
                                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: emp.role != null && emp.role!.isNotEmpty
                                    ? Text(emp.role!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                                    : null,
                                trailing: Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF0A2540),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedEmpIds.add(emp.id);
                                      } else {
                                        selectedEmpIds.remove(emp.id);
                                      }
                                    });
                                  },
                                ),
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedEmpIds.remove(emp.id);
                                    } else {
                                      selectedEmpIds.add(emp.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Done (${selectedEmpIds.length} Selected)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditTaskDialog([TaskModel? existingTask]) {
    final titleCtrl = TextEditingController(text: existingTask?.title ?? '');
    final descCtrl = TextEditingController(text: existingTask?.description ?? '');
    DateTime? dueDate = existingTask?.dueDate ?? DateTime.now().add(const Duration(days: 3));
    DateTime? startDate = existingTask?.startDate ?? DateTime.now();
    String status = _normalizeStatus(existingTask?.status ?? 'Pending');
    
    // Employee Assignment Selection state:
    // 'Single', 'Multiple', 'All', or 'Unassigned'
    String assignMode = 'Single';
    final Set<String> selectedEmpIds = {};
    if (existingTask?.assignedEmployeeId != null) {
      selectedEmpIds.add(existingTask!.assignedEmployeeId!);
      assignMode = 'Single';
    } else if (existingTask != null) {
      assignMode = 'Unassigned';
    } else {
      assignMode = 'Single';
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final List<Map<String, dynamic>> dialogSubModules = <Map<String, dynamic>>[
      for (final s in existingTask?.subModules ?? <TaskSubModule>[])
        <String, dynamic>{
          'id': s.id,
          'title': s.title,
          'status': s.status,
          'description': s.description ?? '',
        }
    ];
    final newSubModuleCtrl = TextEditingController();

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

                      // ASSIGN EMPLOYEE SECTION (Single, Multiple, All, Unassigned)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.person_outline, size: 18, color: Color(0xFF0A2540)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Assign Employees',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                                    ),
                                  ],
                                ),
                                if (selectedEmpIds.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A2540).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${selectedEmpIds.length} Selected',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Option selection buttons: Single, Multiple, All, Unassigned
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildAssignModeChip('Single', Icons.person, assignMode == 'Single', () {
                                    setDialogState(() {
                                      assignMode = 'Single';
                                      if (selectedEmpIds.length > 1) {
                                        final first = selectedEmpIds.first;
                                        selectedEmpIds.clear();
                                        selectedEmpIds.add(first);
                                      } else if (selectedEmpIds.isEmpty && _employees.isNotEmpty) {
                                        selectedEmpIds.add(_employees.first.id);
                                      }
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildAssignModeChip('Multiple', Icons.group, assignMode == 'Multiple', () {
                                    setDialogState(() {
                                      assignMode = 'Multiple';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildAssignModeChip('All (${_employees.length})', Icons.groups, assignMode == 'All', () {
                                    setDialogState(() {
                                      assignMode = 'All';
                                      selectedEmpIds.clear();
                                      selectedEmpIds.addAll(_employees.map((e) => e.id));
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildAssignModeChip('Unassigned', Icons.person_off_outlined, assignMode == 'Unassigned', () {
                                    setDialogState(() {
                                      assignMode = 'Unassigned';
                                      selectedEmpIds.clear();
                                    });
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Content based on selected mode
                            if (assignMode == 'Single') ...[
                              DropdownButtonFormField<String?>(
                                initialValue: selectedEmpIds.isNotEmpty ? selectedEmpIds.first : null,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(),
                                  hintText: 'Select an employee',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Unassigned / General Task'),
                                  ),
                                  ..._employees.map((e) => DropdownMenuItem<String?>(
                                        value: e.id,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: const Color(0xFF0A2540),
                                              child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                                                  style: const TextStyle(fontSize: 10, color: Colors.white)),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            if (e.role != null && e.role!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text('(${e.role})', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                            ],
                                          ],
                                        ),
                                      )),
                                ],
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedEmpIds.clear();
                                    if (val != null) selectedEmpIds.add(val);
                                  });
                                },
                              ),
                            ] else if (assignMode == 'Multiple') ...[
                              InkWell(
                                onTap: () async {
                                  await _showMultiEmployeeSelectModal(context, selectedEmpIds);
                                  setDialogState(() {});
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.touch_app_outlined, size: 18, color: Color(0xFF0B5ED7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedEmpIds.isEmpty
                                              ? 'Tap to select employees...'
                                              : '${selectedEmpIds.length} employee${selectedEmpIds.length > 1 ? 's' : ''} selected',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: selectedEmpIds.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                            color: selectedEmpIds.isNotEmpty ? const Color(0xFF0A2540) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              if (selectedEmpIds.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: selectedEmpIds.map((id) {
                                    final emp = _employees.firstWhere(
                                      (e) => e.id == id,
                                      orElse: () => Employee(id: id, name: 'Employee', status: 'Active'),
                                    );
                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: const Color(0xFF0A2540),
                                        child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                            style: const TextStyle(fontSize: 9, color: Colors.white)),
                                      ),
                                      label: Text(emp.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      deleteIcon: const Icon(Icons.close, size: 14),
                                      onDeleted: () {
                                        setDialogState(() {
                                          selectedEmpIds.remove(id);
                                        });
                                      },
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ] else if (assignMode == 'All') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4EA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF137333).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF137333)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Task will be assigned to all ${_employees.length} employees',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  'This task is not assigned to any specific employee.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ],
                        ),
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
                      const SizedBox(height: 14),

                      // SUB-MODULES / BREAKDOWN SECTION
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF0A2540)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Sub-Modules / Breakdown',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                                    ),
                                  ],
                                ),
                                if (dialogSubModules.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A2540).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${dialogSubModules.length} Sub-modules',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter any sub-module (e.g. Foundation, Wiring, Plastering):',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),

                            // Sub-module Input with integrated Add button
                            TextField(
                              controller: newSubModuleCtrl,
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                hintText: 'Type sub-module name...',
                                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add_circle, color: Color(0xFF0A2540), size: 26),
                                  tooltip: 'Add sub-module',
                                  onPressed: () {
                                    final text = newSubModuleCtrl.text.trim();
                                    if (text.isEmpty) return;
                                    final parts = text.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
                                    if (parts.isNotEmpty) {
                                      setDialogState(() {
                                        for (final p in parts) {
                                          dialogSubModules.add(<String, dynamic>{
                                            'id': '${DateTime.now().millisecondsSinceEpoch}_$p',
                                            'title': p,
                                            'status': 'Pending',
                                            'description': '',
                                          });
                                        }
                                        newSubModuleCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              onSubmitted: (val) {
                                final text = val.trim();
                                if (text.isEmpty) return;
                                final parts = text.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
                                if (parts.isNotEmpty) {
                                  setDialogState(() {
                                    for (final p in parts) {
                                      dialogSubModules.add(<String, dynamic>{
                                        'id': '${DateTime.now().millisecondsSinceEpoch}_$p',
                                        'title': p,
                                        'status': 'Pending',
                                        'description': '',
                                      });
                                    }
                                    newSubModuleCtrl.clear();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),

                            // Full-width Add Button (never cut off, easily tappable)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A2540),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final text = newSubModuleCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  final parts = text.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
                                  if (parts.isNotEmpty) {
                                    setDialogState(() {
                                      for (final p in parts) {
                                        dialogSubModules.add(<String, dynamic>{
                                          'id': '${DateTime.now().millisecondsSinceEpoch}_$p',
                                          'title': p,
                                          'status': 'Pending',
                                          'description': '',
                                        });
                                      }
                                      newSubModuleCtrl.clear();
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Sub-Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),

                            // Sub-modules list
                            if (dialogSubModules.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Column(
                                children: List.generate(dialogSubModules.length, (index) {
                                  final sm = dialogSubModules[index];
                                  final smStatus = _normalizeStatus(sm['status'] ?? 'Pending');
                                  final smColor = _getStatusColor(smStatus);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: smColor.withValues(alpha: 0.15),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: smColor),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            sm['title'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                                          ),
                                        ),
                                        // Status picker
                                        PopupMenuButton<String>(
                                          tooltip: 'Change Sub-module Status',
                                          onSelected: (newSt) {
                                            setDialogState(() {
                                              sm['status'] = newSt;
                                            });
                                          },
                                          itemBuilder: (ctx) => taskStatusOptions.map((st) {
                                            return PopupMenuItem<String>(
                                              value: st,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.circle, size: 10, color: _getStatusColor(st)),
                                                  const SizedBox(width: 8),
                                                  Text(st, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getStatusBg(smStatus),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: smColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle, size: 6, color: smColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  smStatus == 'Ongoing' ? 'On Progress' : smStatus == 'Completed' ? 'Done' : 'Pending',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: smColor),
                                                ),
                                                const SizedBox(width: 2),
                                                Icon(Icons.arrow_drop_down, size: 14, color: smColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            setDialogState(() {
                                              dialogSubModules.removeAt(index);
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.close, size: 16, color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
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

                          // Auto-capture leftover text in newSubModuleCtrl if user forgot to tap Add button
                          final leftover = newSubModuleCtrl.text.trim();
                          if (leftover.isNotEmpty) {
                            final parts = leftover.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
                            for (final p in parts) {
                              dialogSubModules.add(<String, dynamic>{
                                'id': '${DateTime.now().millisecondsSinceEpoch}_$p',
                                'title': p,
                                'status': 'Pending',
                                'description': '',
                              });
                            }
                            newSubModuleCtrl.clear();
                          }

                          final subModulesPayload = dialogSubModules
                              .where((s) => (s['title'] as String).trim().isNotEmpty)
                              .map<Map<String, dynamic>>((s) => <String, dynamic>{
                                    'id': s['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                    'title': (s['title'] as String).trim(),
                                    'status': s['status'] ?? 'Pending',
                                    'description': s['description'] ?? '',
                                  })
                              .toList();

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            if (existingTask == null) {
                              // Create Task(s)
                              if (selectedEmpIds.isEmpty) {
                                final data = {
                                  'title': titleCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'start_date': startDate.toIso8601String().split('T').first,
                                  'due_date': dueDate?.toIso8601String().split('T').first,
                                  'status': status,
                                  'assigned_employee_id': null,
                                  'sub_modules': subModulesPayload,
                                };
                                await _apiService.createTask(widget.siteId, data);
                                messenger.showSnackBar(const SnackBar(content: Text('Task added successfully!')));
                              } else {
                                for (final empId in selectedEmpIds) {
                                  final data = {
                                    'title': titleCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'start_date': startDate.toIso8601String().split('T').first,
                                    'due_date': dueDate?.toIso8601String().split('T').first,
                                    'status': status,
                                    'assigned_employee_id': empId,
                                    'sub_modules': subModulesPayload,
                                  };
                                  await _apiService.createTask(widget.siteId, data);
                                }
                                final empCount = selectedEmpIds.length;
                                messenger.showSnackBar(SnackBar(
                                  content: Text(empCount == 1
                                      ? 'Task added and assigned!'
                                      : 'Task added and assigned to $empCount employees!'),
                                ));
                              }
                            } else {
                              // Update Existing Task
                              final firstEmpId = selectedEmpIds.isNotEmpty ? selectedEmpIds.first : null;
                              final data = {
                                'title': titleCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'start_date': startDate.toIso8601String().split('T').first,
                                'due_date': dueDate?.toIso8601String().split('T').first,
                                'status': status,
                                'assigned_employee_id': firstEmpId,
                                'sub_modules': subModulesPayload,
                              };
                              await _apiService.updateTask(existingTask.id, data);

                              // If multiple employees were selected on an edit, clone task for others
                              if (selectedEmpIds.length > 1) {
                                final remainingEmpIds = selectedEmpIds.skip(1);
                                for (final empId in remainingEmpIds) {
                                  await _apiService.createTask(widget.siteId, {
                                    ...data,
                                    'assigned_employee_id': empId,
                                  });
                                }
                              }

                              final empCount = selectedEmpIds.length;
                              messenger.showSnackBar(SnackBar(
                                content: Text(empCount > 1
                                    ? 'Task updated and assigned to $empCount employees!'
                                    : 'Task updated successfully!'),
                              ));
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

  Widget _buildAssignModeChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2540) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A2540) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF0A2540),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
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
                // SEARCH BAR & OPTION SELECTION MENU
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                    ),
                    const SizedBox(width: 8),
                    _buildSelectionOptionButton(filteredTasks),
                  ],
                ),
                const SizedBox(height: 14),

                // SELECTION MODE BANNER (When active)
                if (_isSelectionMode || _selectedTaskIds.isNotEmpty)
                  _buildSelectionModeBanner(filteredTasks),

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
      bottomNavigationBar: _selectedTaskIds.isNotEmpty ? _buildBulkActionBar() : null,
      floatingActionButton: _selectedTaskIds.isEmpty && PermissionService.instance.canCreate(AppModules.siteTasks)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditTaskDialog(),
              backgroundColor: const Color(0xFF0A2540),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildSelectionOptionButton(List<TaskModel> filteredTasks) {
    return Container(
      decoration: BoxDecoration(
        color: _isSelectionMode ? const Color(0xFF0A2540) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSelectionMode ? const Color(0xFF0A2540) : Colors.grey.shade300,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Task Selection Options',
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSelectionMode ? Icons.check_circle : Icons.checklist_rounded,
              size: 18,
              color: _isSelectionMode ? Colors.white : const Color(0xFF0A2540),
            ),
            const SizedBox(width: 6),
            Text(
              _isSelectionMode ? '${_selectedTaskIds.length} Selected' : 'Select',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isSelectionMode ? Colors.white : const Color(0xFF0A2540),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: _isSelectionMode ? Colors.white : Colors.grey.shade600,
            ),
          ],
        ),
        onSelected: (val) {
          if (val == 'all') {
            _selectAllTasks(filteredTasks);
          } else if (val == 'multiple') {
            _toggleSelectionMode(true);
          } else if (val == 'single') {
            if (filteredTasks.isNotEmpty) {
              _selectSingleTask(filteredTasks.first.id);
            } else {
              _toggleSelectionMode(true);
            }
          } else if (val == 'clear') {
            _clearTaskSelection();
          } else if (val == 'exit') {
            _toggleSelectionMode(false);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'OPTION SELECTION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          PopupMenuItem(
            value: 'all',
            child: Row(
              children: [
                const Icon(Icons.select_all_rounded, size: 18, color: Color(0xFF0A2540)),
                const SizedBox(width: 10),
                Text('Select All (${filteredTasks.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'multiple',
            child: Row(
              children: const [
                Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF0B5ED7)),
                SizedBox(width: 10),
                Text('Select Multiple', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'single',
            child: Row(
              children: const [
                Icon(Icons.radio_button_checked, size: 18, color: Color(0xFF137333)),
                SizedBox(width: 10),
                Text('Select Single', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_isSelectionMode || _selectedTaskIds.isNotEmpty) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: const [
                  Icon(Icons.deselect_outlined, size: 18, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('Deselect All', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'exit',
              child: Row(
                children: const [
                  Icon(Icons.close_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Exit Selection Mode', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionModeBanner(List<TaskModel> filteredTasks) {
    final allVisibleSelected = filteredTasks.isNotEmpty &&
        filteredTasks.every((t) => _selectedTaskIds.contains(t.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2540),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2540).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (allVisibleSelected) {
                _clearTaskSelection();
              } else {
                _selectAllTasks(filteredTasks);
              }
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    allVisibleSelected
                        ? Icons.check_box
                        : (_selectedTaskIds.isNotEmpty ? Icons.indeterminate_check_box : Icons.check_box_outline_blank),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allVisibleSelected ? 'Deselect All' : 'Select All (${filteredTasks.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedTaskIds.length} Selected',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _toggleSelectionMode(false),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isBulkActionInProgress
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Processing batch operation...', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF0A2540),
                    child: Text(
                      '${_selectedTaskIds.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                  ),
                  const Spacer(),
                  // Assign Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A2540),
                      side: const BorderSide(color: Color(0xFF0A2540)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showBulkAssignDialog,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                    label: const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // Change Status Button with Popup Menu
                  PopupMenuButton<String>(
                    tooltip: 'Change Status for Selected',
                    onSelected: _bulkUpdateStatus,
                    itemBuilder: (context) => taskStatusOptions.map((st) {
                      return PopupMenuItem<String>(
                        value: st,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: _getStatusColor(st)),
                            const SizedBox(width: 8),
                            Text('Mark as $st', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0B5ED7).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sync_alt_rounded, size: 15, color: Color(0xFF0B5ED7)),
                          SizedBox(width: 4),
                          Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0B5ED7)),
                          ),
                          Icon(Icons.arrow_drop_down, size: 15, color: Color(0xFF0B5ED7)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Delete Selected Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _confirmBulkDelete,
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
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
    final isSelected = _selectedTaskIds.contains(task.id);
    final currentNormStatus = _normalizeStatus(task.status);
    final statusColor = _getStatusColor(currentNormStatus);
    final statusBg = _getStatusBg(currentNormStatus);

    final assigneeName = task.assignedEmployeeName ?? 'Unassigned';
    final assigneeAvatar = assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : 'U';
    final dueDateStr = task.dueDate != null ? dateFormat.format(task.dueDate!) : 'Ongoing';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF0B5ED7) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF0B5ED7).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_isSelectionMode) {
              _toggleTaskSelection(task.id);
            } else {
              TaskDetailsSheet.show(
                context,
                task: task,
                onUpdated: _loadTasks,
              );
            }
          },
          onLongPress: () {
            _toggleTaskSelection(task.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF0A2540),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (_) => _toggleTaskSelection(task.id),
                      ),
                    ),
                  ),
                ],
                Expanded(
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

                      // SUB-MODULES PREVIEW & PROGRESS
                      if (task.subModules.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        // Progress Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_tree_outlined, size: 13, color: Color(0xFF0A2540)),
                                const SizedBox(width: 4),
                                Text(
                                  'Sub-Modules (${task.completedSubModulesCount}/${task.subModules.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                ),
                              ],
                            ),
                            Text(
                              '${(task.subModulesProgress * 100).toInt()}% Done',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: task.completedSubModulesCount == task.subModules.length
                                    ? const Color(0xFF137333)
                                    : const Color(0xFF0B5ED7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.subModulesProgress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              task.completedSubModulesCount == task.subModules.length
                                  ? const Color(0xFF137333)
                                  : const Color(0xFF0B5ED7),
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sub-module pills (design: done, code: on progress, deploy: pending)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: task.subModules.map((sm) {
                            final smNorm = _normalizeStatus(sm.status);
                            final smColor = _getStatusColor(smNorm);
                            final smBg = _getStatusBg(smNorm);
                            final smLabel = smNorm == 'Ongoing'
                                ? 'On Progress'
                                : smNorm == 'Completed'
                                    ? 'Done'
                                    : 'Pending';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: smBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: smColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 6, color: smColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    sm.title,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0A2540),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($smLabel)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: smColor,
                                    ),
                                  ),
                                  if (sm.description != null && sm.description!.trim().isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.notes_rounded, size: 12, color: Colors.blueGrey),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        // If any sub-module has notes/descriptions, show quick preview
                        if (task.subModules.any((s) => s.description != null && s.description!.trim().isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: task.subModules
                                  .where((s) => s.description != null && s.description!.trim().isNotEmpty)
                                  .map((s) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${s.title}: ',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                            ),
                                            Expanded(
                                              child: Text(
                                                s.description!,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            TaskDetailsSheet.show(
                              context,
                              task: task,
                              onUpdated: _loadTasks,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_circle_outline, size: 12, color: Color(0xFF0B5ED7)),
                                SizedBox(width: 4),
                                Text(
                                  '+ Add Sub-modules',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Footer: Assignee, Due Date, and Actions Menu (Select/Edit/Delete)
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
                              if (val == 'select') {
                                _toggleTaskSelection(task.id);
                              } else if (val == 'select_single') {
                                _selectSingleTask(task.id);
                              } else if (val == 'sub_modules') {
                                TaskDetailsSheet.show(
                                  context,
                                  task: task,
                                  onUpdated: _loadTasks,
                                );
                              } else if (val == 'edit') {
                                _showAddEditTaskDialog(task);
                              } else if (val == 'delete') {
                                _confirmDeleteTask(task);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'sub_modules',
                                child: Row(
                                  children: const [
                                    Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF0B5ED7)),
                                    SizedBox(width: 8),
                                    Text('Update Sub-modules', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0B5ED7))),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'select',
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                      size: 16,
                                      color: const Color(0xFF0A2540),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isSelected ? 'Deselect Task' : 'Select Multiple'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'select_single',
                                child: Row(
                                  children: [
                                    Icon(Icons.radio_button_checked, size: 16, color: Color(0xFF137333)),
                                    SizedBox(width: 8),
                                    Text('Select Single'),
                                  ],
                                ),
                              ),
                              if (PermissionService.instance.canEdit(AppModules.siteTasks)) ...[
                                const PopupMenuDivider(),
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
                              ],
                              if (PermissionService.instance.canDelete(AppModules.siteTasks)) ...[
                                const PopupMenuDivider(),
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
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
