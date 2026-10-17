import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/task_model.dart';
import '../../../../services/api_service.dart';

class TaskDetailsSheet extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onUpdated;
  final VoidCallback? onOpenSite;

  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.onUpdated,
    this.onOpenSite,
  });

  static Future<void> show(
    BuildContext context, {
    required TaskModel task,
    required VoidCallback onUpdated,
    VoidCallback? onOpenSite,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskDetailsSheet(
        task: task,
        onUpdated: onUpdated,
        onOpenSite: onOpenSite,
      ),
    );
  }

  @override
  State<TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<TaskDetailsSheet> {
  final ApiService _apiService = ApiService();
  late String _overallStatus;
  late List<Map<String, dynamic>> _subModules;
  late List<TextEditingController> _subModuleDescControllers;
  late List<TextEditingController> _subModuleTitleControllers;
  final TextEditingController _newSubModuleCtrl = TextEditingController();
  bool _isSaving = false;

  static const List<String> statusList = ['Pending', 'Ongoing', 'Completed'];

  @override
  void initState() {
    super.initState();
    _overallStatus = _normalizeStatus(widget.task.status);
    _subModules = <Map<String, dynamic>>[
      for (final s in widget.task.subModules)
        <String, dynamic>{
          'id': s.id,
          'title': s.title,
          'status': _normalizeStatus(s.status),
          'description': s.description ?? '',
        }
    ];

    _subModuleDescControllers = _subModules.map((s) => TextEditingController(text: s['description'])).toList();
    _subModuleTitleControllers = _subModules.map((s) => TextEditingController(text: s['title'])).toList();
  }

  @override
  void dispose() {
    for (final c in _subModuleDescControllers) {
      c.dispose();
    }
    for (final c in _subModuleTitleControllers) {
      c.dispose();
    }
    _newSubModuleCtrl.dispose();
    super.dispose();
  }

  static String _normalizeStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('progress') || lower == 'ongoing') return 'Ongoing';
    if (lower == 'completed' || lower == 'done') return 'Completed';
    return 'Pending';
  }

  static Color _getStatusColor(String status) {
    final norm = _normalizeStatus(status);
    if (norm == 'Ongoing') return const Color(0xFF0B5ED7);
    if (norm == 'Completed') return const Color(0xFF137333);
    return const Color(0xFFC2410C);
  }

  static Color _getStatusBg(String status) {
    final norm = _normalizeStatus(status);
    if (norm == 'Ongoing') return const Color(0xFFEFF6FF);
    if (norm == 'Completed') return const Color(0xFFE6F4EA);
    return const Color(0xFFFFF7ED);
  }

  static String _getStatusLabel(String status) {
    final norm = _normalizeStatus(status);
    if (norm == 'Ongoing') return 'On Progress';
    if (norm == 'Completed') return 'Done';
    return 'Pending';
  }

  void _addSubModule(String title) {
    final parts = title.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return;

    setState(() {
      for (final p in parts) {
        final newId = '${DateTime.now().millisecondsSinceEpoch}_${_subModules.length}';
        _subModules.add(<String, dynamic>{
          'id': newId,
          'title': p,
          'status': 'Pending',
          'description': '',
        });
        _subModuleDescControllers.add(TextEditingController());
        _subModuleTitleControllers.add(TextEditingController(text: p));
      }
      _newSubModuleCtrl.clear();

      _autoUpdateOverallStatus();
    });
  }

  void _removeSubModule(int index) {
    setState(() {
      _subModules.removeAt(index);
      _subModuleDescControllers[index].dispose();
      _subModuleDescControllers.removeAt(index);
      _subModuleTitleControllers[index].dispose();
      _subModuleTitleControllers.removeAt(index);

      _autoUpdateOverallStatus();
    });
  }

  void _updateSubModuleStatus(int index, String newStatus) {
    setState(() {
      _subModules[index]['status'] = _normalizeStatus(newStatus);
      _autoUpdateOverallStatus();
    });
  }

  void _autoUpdateOverallStatus() {
    if (_subModules.isEmpty) return;

    final allDone = _subModules.every((s) => _normalizeStatus(s['status']) == 'Completed');
    final hasOngoing = _subModules.any((s) => _normalizeStatus(s['status']) == 'Ongoing');
    final hasDone = _subModules.any((s) => _normalizeStatus(s['status']) == 'Completed');

    if (allDone) {
      _overallStatus = 'Completed';
    } else if (hasOngoing || hasDone) {
      if (_overallStatus == 'Pending') {
        _overallStatus = 'Ongoing';
      }
    }
  }

  Future<void> _saveChanges() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    // Auto-capture leftover text if user typed in _newSubModuleCtrl without clicking Add
    final leftover = _newSubModuleCtrl.text.trim();
    if (leftover.isNotEmpty) {
      final parts = leftover.split(RegExp(r'[\n,]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final p in parts) {
        final newId = '${DateTime.now().millisecondsSinceEpoch}_${_subModules.length}';
        _subModules.add(<String, dynamic>{
          'id': newId,
          'title': p,
          'status': 'Pending',
          'description': '',
        });
        _subModuleDescControllers.add(TextEditingController());
        _subModuleTitleControllers.add(TextEditingController(text: p));
      }
      _newSubModuleCtrl.clear();
      _autoUpdateOverallStatus();
    }

    // Sync titles and descriptions from controllers
    for (int i = 0; i < _subModules.length; i++) {
      _subModules[i]['title'] = _subModuleTitleControllers[i].text.trim();
      _subModules[i]['description'] = _subModuleDescControllers[i].text.trim();
    }

    // Filter out empty titles
    final validSubModules = _subModules
        .where((s) => (s['title'] as String).isNotEmpty)
        .map<Map<String, dynamic>>((s) => <String, dynamic>{
              'id': s['id'],
              'title': s['title'],
              'status': s['status'],
              'description': s['description'],
              'updated_at': DateTime.now().toIso8601String(),
            })
        .toList();

    setState(() => _isSaving = true);

    try {
      await _apiService.updateTask(widget.task.id, {
        'status': _overallStatus,
        'sub_modules': validSubModules,
      });

      widget.onUpdated();
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Task and sub-modules updated successfully!'),
          backgroundColor: Color(0xFF137333),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final doneCount = _subModules.where((s) => _normalizeStatus(s['status']) == 'Completed').length;
    final progress = _subModules.isEmpty ? 0.0 : doneCount / _subModules.length;

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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF0B5ED7)),
                      const SizedBox(width: 4),
                      Text(
                        widget.task.siteName ?? widget.task.siteCode ?? 'Project Site',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0B5ED7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBg(_overallStatus),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(_overallStatus).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: _getStatusColor(_overallStatus)),
                      const SizedBox(width: 5),
                      Text(
                        _getStatusLabel(_overallStatus),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getStatusColor(_overallStatus)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Task Heading & Description
                Text(
                  widget.task.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                ),
                if (widget.task.description != null && widget.task.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      widget.task.description!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Meta Info: Assignee & Dates
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: widget.task.assignedEmployeeName != null
                            ? const Color(0xFF137333)
                            : Colors.grey.shade400,
                        child: Text(
                          widget.task.assignedEmployeeName?.isNotEmpty == true
                              ? widget.task.assignedEmployeeName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.task.assignedEmployeeName ?? 'Unassigned Task',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.task.dueDate != null) ...[
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${dateFormat.format(widget.task.dueDate!)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // OVERALL TASK STATUS SELECTOR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Task Status',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                    Text(
                      'Update as Needed',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: statusList.map((st) {
                    final isSelected = _overallStatus == st;
                    final stColor = _getStatusColor(st);
                    final stBg = _getStatusBg(st);
                    final stLabel = _getStatusLabel(st);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setState(() => _overallStatus = st),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? stBg : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? stColor : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  size: 13,
                                  color: isSelected ? stColor : Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  stLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? stColor : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // SUB-MODULES HEADER & PROGRESS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF0A2540)),
                        const SizedBox(width: 6),
                        const Text(
                          'Task Sub-Modules',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A2540).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_subModules.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                        ),
                      ],
                    ),
                    if (_subModules.isNotEmpty)
                      Text(
                        '$doneCount of ${_subModules.length} Done (${(progress * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: doneCount == _subModules.length ? const Color(0xFF137333) : const Color(0xFF0B5ED7),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Progress Bar
                if (_subModules.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        doneCount == _subModules.length ? const Color(0xFF137333) : const Color(0xFF0B5ED7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // SUB-MODULES LIST
                if (_subModules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.playlist_add_rounded, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            'No sub-modules added yet',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add sub-modules like Design, Code, Deploy below.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_subModules.length, (index) {
                    final sm = _subModules[index];
                    final currentSmStatus = _normalizeStatus(sm['status']);
                    final descCtrl = _subModuleDescControllers[index];
                    final titleCtrl = _subModuleTitleControllers[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(currentSmStatus).withValues(alpha: 0.35),
                          width: 1.2,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Title & Delete
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStatusBg(currentSmStatus),
                                  border: Border.all(color: _getStatusColor(currentSmStatus)),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(currentSmStatus),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: titleCtrl,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2540)),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                                    border: InputBorder.none,
                                    hintText: 'Sub-module title...',
                                  ),
                                  onChanged: (val) {
                                    sm['title'] = val;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                tooltip: 'Remove sub-module',
                                onPressed: () => _removeSubModule(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Status selector chips (Pending, On Progress, Done)
                          Row(
                            children: statusList.map((st) {
                              final isSelected = currentSmStatus == st;
                              final color = _getStatusColor(st);
                              final bg = _getStatusBg(st);
                              final label = _getStatusLabel(st);

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    onTap: () => _updateSubModuleStatus(index, st),
                                    borderRadius: BorderRadius.circular(8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? bg : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? color : Colors.grey.shade300,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                                            size: 11,
                                            color: isSelected ? color : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? color : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),

                          // Row 3: Description/Notes input
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: descCtrl,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              minLines: 1,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Add note / update description (optional)...',
                                hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                                prefixIcon: Icon(Icons.notes_rounded, size: 14, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (val) {
                                sm['description'] = val;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 6),

                // ADD SUB-MODULE INPUT
                TextField(
                  controller: _newSubModuleCtrl,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintText: 'Type sub-module name (e.g. Foundation, Wiring)...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: const Icon(Icons.add_task_rounded, size: 18, color: Color(0xFF0A2540)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF0A2540), size: 26),
                      tooltip: 'Add sub-module',
                      onPressed: () => _addSubModule(_newSubModuleCtrl.text),
                    ),
                  ),
                  onSubmitted: (val) => _addSubModule(val),
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
                    onPressed: () => _addSubModule(_newSubModuleCtrl.text),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Sub-Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                if (widget.onOpenSite != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B5ED7),
                        side: const BorderSide(color: Color(0xFF0B5ED7)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenSite!();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Open Project Site Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // BOTTOM ACTION BAR
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Updates',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
