import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';
import '../../models/employee_model.dart';
import '../../models/role_model.dart';
import '../../models/site_model.dart';
import '../../services/employee_id_service.dart';
import 'add_edit_employee_screen.dart';
import '../roles/employee_custom_permissions_screen.dart';
import '../../core/widgets/profile_avatar_button.dart';
import 'widgets/employee_location_sheet.dart';

class EmployeeListScreen extends StatefulWidget {
  final int initialTab;
  const EmployeeListScreen({super.key, this.initialTab = 0});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late Future<List<Employee>> _employeesFuture;
  List<AppRole> _availableRoles = [];
  List<Site> _availableSites = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadEmployees();
    _loadMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMeta() async {
    try {
      final roles = await PermissionService.instance.fetchAllRoles();
      final sites = await _apiService.getSites();
      if (mounted) {
        setState(() {
          _availableRoles = roles;
          _availableSites = sites;
        });
      }
    } catch (_) {}
  }

  void _loadEmployees() {
    setState(() {
      _employeesFuture = _apiService.getEmployees().then(
          (data) => data.map((json) => Employee.fromJson(json)).toList()).catchError((err) async {
        // Fallback to Supabase direct query
        final res = await Supabase.instance.client
            .from('employees')
            .select('*, site:sites(name)')
            .order('created_at', ascending: false);
        return (res as List).map((json) => Employee.fromJson(json)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ps = PermissionService.instance;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Employees & Access', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEmployees,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: FutureBuilder<List<Employee>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 54, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadEmployees,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allEmployees = snapshot.data ?? [];
          final pendingEmployees = allEmployees
              .where((e) => e.status.trim().toLowerCase() == 'pending')
              .toList();
          final activeEmployees = allEmployees
              .where((e) => e.status.trim().toLowerCase() == 'active')
              .toList();
          final otherEmployees = allEmployees
              .where((e) =>
                  e.status.trim().toLowerCase() != 'pending' &&
                  e.status.trim().toLowerCase() != 'active')
              .toList();

          return Column(
            children: [
              // Pending Approval Alert Banner for Super Admin / Admin
              if (pendingEmployees.isNotEmpty && (ps.isSuperAdmin || ps.isAdmin))
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pendingEmployees.length} Pending Registration Request${pendingEmployees.length > 1 ? "s" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                            ),
                            const Text(
                              'Users cannot log in until admitted by Super Admin.',
                              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Active'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${activeEmployees.length}',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Pending'),
                          if (pendingEmployees.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade500,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pendingEmployees.length}',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Declined / Other'),
                          if (otherEmployees.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${otherEmployees.length}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveList(activeEmployees),
                    _buildPendingList(pendingEmployees),
                    _buildOtherList(otherEmployees),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PermissionService.instance.canCreate(AppModules.employees)
          ? FloatingActionButton(
              onPressed: () => _navigateToAddEmployee(),
              tooltip: 'Add Employee',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildActiveList(List<Employee> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No active employees found', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _navigateToAddEmployee(),
              child: const Text('Add New Employee'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadEmployees();
        await _employeesFuture;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildEmployeeCard(list[index]),
      ),
    );
  }

  Widget _buildPendingList(List<Employee> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          _loadEmployees();
          await _employeesFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 48),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_user_rounded, size: 64, color: Colors.green.shade600),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Pending Registrations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
            ),
            const SizedBox(height: 8),
            Text(
              'When new users sign up, they will appear here waiting for Super Admin approval before they can log in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadEmployees();
        await _employeesFuture;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildPendingCard(list[index]),
      ),
    );
  }

  Widget _buildOtherList(List<Employee> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          _loadEmployees();
          await _employeesFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 48),
            Center(
              child: Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Declined or Inactive Users',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadEmployees();
        await _employeesFuture;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildOtherCard(list[index]),
      ),
    );
  }

  Widget _buildPendingCard(Employee emp) {
    final ps = PermissionService.instance;
    final canAdmit = ps.isSuperAdmin || ps.isAdmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.amber.shade100,
                  backgroundImage: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(emp.profileImageUrl!)
                      : null,
                  onBackgroundImageError: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
                      ? (_, __) {}
                      : null,
                  child: (emp.profileImageUrl == null || emp.profileImageUrl!.isEmpty)
                      ? Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              emp.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0A2540)),
                            ),
                          ),
                          if (emp.employeeId != null && emp.employeeId!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Text(
                                emp.employeeId!,
                                style: const TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              emp.email ?? 'No email',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (emp.phone != null && emp.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              emp.phone!,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pending Review',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (canAdmit) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _confirmDecline(emp),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve & Admit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _showApproveDialog(emp),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Only Super Admin or Admin can approve or decline this user.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtherCard(Employee emp) {
    final ps = PermissionService.instance;
    final canAdmit = ps.isSuperAdmin || ps.isAdmin;
    final isDeclined = emp.status.toLowerCase() == 'declined';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: isDeclined ? Colors.red.shade100 : Colors.grey.shade200,
          backgroundImage: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
              ? NetworkImage(emp.profileImageUrl!)
              : null,
          onBackgroundImageError: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
              ? (_, __) {}
              : null,
          child: (emp.profileImageUrl == null || emp.profileImageUrl!.isEmpty)
              ? Text(
                  emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDeclined ? Colors.red.shade800 : Colors.grey.shade700,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (emp.employeeId != null && emp.employeeId!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  emp.employeeId!,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(emp.email ?? emp.role ?? 'No details', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.location_on_outlined,
                color: emp.isOnline ? const Color(0xFF16A34A) : Colors.grey.shade600,
                size: 20,
              ),
              tooltip: 'Locate Employee',
              onPressed: () => EmployeeLocationSheet.show(context, emp),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDeclined ? Colors.red.shade50 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                emp.status,
                style: TextStyle(
                  color: isDeclined ? Colors.red.shade800 : Colors.grey.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (canAdmit) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                tooltip: 'Approve / Re-admit',
                onPressed: () => _showApproveDialog(emp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    final ps = PermissionService.instance;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue[100],
          backgroundImage: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
              ? NetworkImage(emp.profileImageUrl!)
              : null,
          onBackgroundImageError: (emp.profileImageUrl != null && emp.profileImageUrl!.isNotEmpty)
              ? (_, __) {}
              : null,
          child: (emp.profileImageUrl == null || emp.profileImageUrl!.isEmpty)
              ? Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue))
              : null,
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
                  Expanded(
                    child: Text(
                      'Site: ${emp.assignedSiteName}',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.location_on_outlined,
                color: emp.isOnline ? const Color(0xFF16A34A) : const Color(0xFF0A2540),
                size: 22,
              ),
              tooltip: 'Locate Employee',
              onPressed: () => EmployeeLocationSheet.show(context, emp),
            ),
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
                if (val == 'locate') {
                  EmployeeLocationSheet.show(context, emp);
                } else if (val == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditEmployeeScreen(employee: emp),
                    ),
                  ).then((_) => _loadEmployees());
                } else if (val == 'permissions') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeCustomPermissionsScreen(employee: emp),
                    ),
                  ).then((_) => _loadEmployees());
                } else if (val == 'change_password') {
                  _showChangePasswordDialog(emp);
                } else if (val == 'decline') {
                  _confirmDecline(emp);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'locate',
                  child: Row(
                    children: [
                      Icon(Icons.location_searching_rounded, size: 18, color: Color(0xFF0A2540)),
                      SizedBox(width: 8),
                      Text('Locate Employee'),
                    ],
                  ),
                ),
                if (ps.canEdit(AppModules.employees))
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
                if (ps.isAdmin || ps.canView(AppModules.roleManagement))
                  const PopupMenuItem(
                    value: 'permissions',
                    child: Row(
                      children: [
                        Icon(Icons.security_rounded, size: 18, color: Color(0xFF8E24AA)),
                        SizedBox(width: 8),
                        Text('Role & Permissions'),
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
                if (ps.isSuperAdmin)
                  PopupMenuItem(
                    value: 'decline',
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text('Decline / Suspend', style: TextStyle(color: Colors.red.shade700)),
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

  Future<void> _showApproveDialog(Employee emp) async {
    String selectedRoleName = emp.role ?? 'Employee';
    String? selectedRoleId;
    String? selectedSiteId = emp.assignedSiteId;

    if (_availableRoles.isNotEmpty) {
      final match = _availableRoles.firstWhere(
        (r) => r.name.toLowerCase() == selectedRoleName.toLowerCase(),
        orElse: () => _availableRoles.first,
      );
      selectedRoleId = match.id.isNotEmpty ? match.id : null;
      selectedRoleName = match.name;
    }

    bool isSubmitting = false;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified_user_rounded, color: Colors.green.shade700, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admit User Access',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                            ),
                            Text(
                              'Approve registration for ${emp.name}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (errorMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),

                  // User Info Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.email, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                emp.email ?? 'No email',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        if (emp.phone != null && emp.phone!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(emp.phone!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Selector
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoleId,
                    decoration: const InputDecoration(
                      labelText: 'Assign Role / Access Level',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined),
                      isDense: true,
                    ),
                    items: _availableRoles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r.id,
                        child: Text('${r.name}${r.isSystem ? "" : " (Custom)"}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = _availableRoles.firstWhere((r) => r.id == val);
                        setSheetState(() {
                          selectedRoleId = val;
                          selectedRoleName = matched.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Site Selector (Optional)
                  DropdownButtonFormField<String>(
                    initialValue: selectedSiteId,
                    decoration: const InputDecoration(
                      labelText: 'Assign Site (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_outlined),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None (General Staff)'),
                      ),
                      ..._availableSites.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setSheetState(() {
                        selectedSiteId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 22),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() {
                                    isSubmitting = true;
                                    errorMsg = null;
                                  });

                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    // Ensure employee has a valid ANCC-EMP-(number) ID
                                    String? empId = emp.employeeId;
                                    if (empId == null || empId.trim().isEmpty) {
                                      empId = await EmployeeIdService.fetchNextEmployeeId();
                                    }

                                    // Call backend API
                                    try {
                                      await _apiService.approveEmployee(
                                        emp.id,
                                        role: selectedRoleName,
                                        roleId: selectedRoleId,
                                        siteId: selectedSiteId,
                                      );
                                    } catch (_) {
                                      // Fallback to direct Supabase update
                                      await Supabase.instance.client.from('employees').update({
                                        'status': 'Active',
                                        'role': selectedRoleName,
                                        if (selectedRoleId != null) 'role_id': selectedRoleId,
                                        'assigned_site_id': selectedSiteId,
                                        'employee_id': empId,
                                      }).eq('id', emp.id);
                                    }

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('✓ ${emp.name} admitted successfully! User can now sign in.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadEmployees();
                                  } catch (e) {
                                    setSheetState(() {
                                      isSubmitting = false;
                                      errorMsg = e.toString().replaceAll('Exception: ', '');
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Approve & Admit', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDecline(Employee emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 10),
            const Text('Decline Request?'),
          ],
        ),
        content: Text(
          'Are you sure you want to decline registration for "${emp.name}"?\n\nThe user will NOT be permitted to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline Access'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        try {
          await _apiService.declineEmployee(emp.id);
        } catch (_) {
          await Supabase.instance.client
              .from('employees')
              .update({'status': 'Declined'})
              .eq('id', emp.id);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Registration for ${emp.name} has been declined.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        _loadEmployees();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error declining user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
