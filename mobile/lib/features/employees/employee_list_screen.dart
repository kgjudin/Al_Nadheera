import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/employee_model.dart';
import 'add_edit_employee_screen.dart';
import '../../core/widgets/profile_avatar_button.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Employee>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  void _loadEmployees() {
    setState(() {
      _employeesFuture = _apiService.getEmployees().then(
          (data) => data.map((json) => Employee.fromJson(json)).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Employees', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadEmployees();
          await _employeesFuture;
        },
        child: FutureBuilder<List<Employee>>(
          future: _employeesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No employees found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToAddEmployee(),
                      child: const Text('Add New Employee'),
                    ),
                  ],
                ),
              );
            }

            final employees = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                return _buildEmployeeCard(emp);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEmployee(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue[100],
          backgroundImage: emp.profileImageUrl != null ? NetworkImage(emp.profileImageUrl!) : null,
          child: emp.profileImageUrl == null ? Text(emp.name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)) : null,
        ),
        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(emp.role ?? 'No Role', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            if (emp.assignedSiteName != null)
              Row(
                children: [
                  const Icon(Icons.business, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Site: ${emp.assignedSiteName}', style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: emp.status == 'Active' ? Colors.green[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                emp.status,
                style: TextStyle(
                  color: emp.status == 'Active' ? Colors.green[800] : Colors.grey[800],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (val) {
                if (val == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditEmployeeScreen(employee: emp),
                    ),
                  ).then((_) => _loadEmployees());
                } else if (val == 'change_password') {
                  _showChangePasswordDialog(emp);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'change_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Change Password'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditEmployeeScreen(employee: emp),
            ),
          ).then((_) => _loadEmployees());
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog(Employee emp) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool obscureConfirm = true;
    String? errorMsg;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update password for ${emp.name}:',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    if (errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMsg!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final pwd = passwordCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();

                          if (pwd.length < 6) {
                            setDialogState(() {
                              errorMsg = 'Password must be at least 6 characters';
                            });
                            return;
                          }
                          if (pwd != confirm) {
                            setDialogState(() {
                              errorMsg = 'Passwords do not match';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _apiService.changeEmployeePassword(emp.id, pwd);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToAddEmployee() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditEmployeeScreen()),
    ).then((_) => _loadEmployees());
  }
}
