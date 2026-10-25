import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_modules.dart';
import '../../models/task_model.dart';
import '../../services/permission_service.dart';
import '../profile/profile_settings_screen.dart';
import '../ipc/ipc_list_screen.dart';
import '../document_templates/document_template_settings_screen.dart';
import '../sites/tasks/widgets/task_details_sheet.dart';
import '../sites/site_details_screen.dart';

class DashboardGreetingView extends StatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;
  final Function(String moduleKey)? onNavigateToModule;

  const DashboardGreetingView({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToModule,
  });

  @override
  State<DashboardGreetingView> createState() => _DashboardGreetingViewState();
}

class _DashboardGreetingViewState extends State<DashboardGreetingView> {
  final _supabase = Supabase.instance.client;
  final _permissionService = PermissionService.instance;

  String _userName = 'Team Member';
  String _userRole = 'Employee';
  String? _userAvatarUrl;
  String? _assignedSiteId;
  String? _assignedSiteName;
  String? _employeeId;

  List<TaskModel> _myTasks = [];
  bool _isLoadingTasks = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchMyTasks();
  }

  void _openModule(String moduleKey, int fallbackTab) {
    if (widget.onNavigateToModule != null) {
      widget.onNavigateToModule!(moduleKey);
    } else if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(fallbackTab);
    }
  }

  Future<void> _loadUserInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('employees')
          .select('id, name, role, profile_image_url, assigned_site_id, site:sites(name)')
          .or('id.eq.${user.id},email.ilike.${user.email ?? ''}')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (res != null) {
            _employeeId = res['id']?.toString() ?? user.id;
            _userName = res['name']?.toString() ?? user.userMetadata?['name'] ?? 'Team Member';
            _userRole = res['role']?.toString() ?? _permissionService.currentRole;
            _userAvatarUrl = res['profile_image_url']?.toString();
            _assignedSiteId = res['assigned_site_id']?.toString();
            if (res['site'] != null && res['site'] is Map) {
              _assignedSiteName = res['site']['name']?.toString();
            }
          } else {
            _employeeId = user.id;
            _userName = user.userMetadata?['name']?.toString() ?? 'Team Member';
            _userRole = user.userMetadata?['role']?.toString() ?? _permissionService.currentRole;
            _userAvatarUrl = user.userMetadata?['avatar_url']?.toString();
          }
        });
      }
      _fetchMyTasks();
    } catch (e) {
      debugPrint('Error loading user info in greeting view: $e');
    }
  }

  Future<void> _fetchMyTasks() async {
    final user = _supabase.auth.currentUser;
    final empId = _employeeId ?? user?.id;

    if (empId == null) {
      if (mounted) setState(() => _isLoadingTasks = false);
      return;
    }

    try {
      final res = await _supabase
          .from('tasks')
          .select('*, site:sites(name)')
          .eq('assigned_employee_id', empId)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _myTasks = (res as List).map((j) => TaskModel.fromJson(j)).toList();
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading my tasks in greeting view: $e');
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  String _getGreetingPhrase() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(now);
    final greeting = _getGreetingPhrase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _permissionService.loadUserPermissions();
            await _loadUserInfo();
            await _fetchMyTasks();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Top Header Bar with Logo and Profile
              _buildTopBar(context),
              const SizedBox(height: 18),

              // 2. Hero Greeting Banner Card
              _buildHeroGreetingCard(greeting, formattedDate),
              const SizedBox(height: 18),

              // 3. Assigned Site Banner (if assigned)
              if (_assignedSiteName != null && _assignedSiteName!.isNotEmpty) ...[
                _buildAssignedSiteCard(),
                const SizedBox(height: 18),
              ],

              // 4. Section: Accessible Workspace Modules
              _buildSectionTitle(
                title: 'YOUR ACCESSIBLE WORKSPACES',
                subtitle: 'Tap any module below to jump directly into your daily tools',
                icon: Icons.dashboard_customize_rounded,
              ),
              const SizedBox(height: 12),
              _buildAccessibleModulesGrid(context),
              const SizedBox(height: 24),

              // 5. Section: My Assigned Tasks Preview
              _buildSectionTitle(
                title: 'MY ASSIGNED TASKS',
                subtitle: 'Active checklists & project assignments assigned to you',
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildMyTasksSection(context),
              const SizedBox(height: 24),

              // 6. Support & Permissions Info Card
              _buildAccessInfoCard(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand logo & title
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/al_nadheera_emblem.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.foundation_rounded,
                  color: Color(0xFF0A2540),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AL NADHEERA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFF0A2540),
                  ),
                ),
                Text(
                  'CONSTRUCTION & CONTRACTING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF0B5ED7),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Profile Avatar Button
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
            ).then((_) => _loadUserInfo());
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0B5ED7).withValues(alpha: 0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
              backgroundImage: _userAvatarUrl != null ? NetworkImage(_userAvatarUrl!) : null,
              child: _userAvatarUrl == null
                  ? Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGreetingCard(String greeting, String formattedDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A2540),
            Color(0xFF0F3B66),
            Color(0xFF0B5ED7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2540).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                greeting.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _userRole.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hello, $_userName! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formattedDate,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Welcome to your Al Nadheera workspace. Choose an accessible module below to get started.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedSiteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0B5ED7).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFF0B5ED7), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT ASSIGNED SITE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _assignedSiteName ?? 'Project Site',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2540),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2540),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (_assignedSiteId != null && _assignedSiteId!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SiteDetailsScreen(siteId: _assignedSiteId!)),
                );
              } else {
                _openModule(AppModules.sites, 1);
              }
            },
            child: const Text('Open Site', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF0B5ED7)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAccessibleModulesGrid(BuildContext context) {
    // List of modules the user has view access to
    final items = <_WorkspaceItem>[];

    if (_permissionService.canView(AppModules.sites)) {
      items.add(_WorkspaceItem(
        title: 'Project Sites',
        description: 'Site progress, daily logs & tasks',
        icon: Icons.business_rounded,
        iconColor: const Color(0xFF0B5ED7),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => _openModule(AppModules.sites, 1),
      ));
    }

    if (_permissionService.canView(AppModules.chat)) {
      items.add(_WorkspaceItem(
        title: 'Direct Chat',
        description: 'Message teammates & site teams',
        icon: Icons.chat_bubble_rounded,
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
        onTap: () => _openModule(AppModules.chat, 4),
      ));
    }

    if (_permissionService.canView(AppModules.products)) {
      items.add(_WorkspaceItem(
        title: 'Materials & Specs',
        description: 'Item catalog & material rates',
        icon: Icons.inventory_2_rounded,
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
        onTap: () => _openModule(AppModules.products, 6),
      ));
    }

    if (_permissionService.canView(AppModules.personal)) {
      items.add(_WorkspaceItem(
        title: 'Personal Notes',
        description: 'Private workspace data & folders',
        icon: Icons.folder_shared_rounded,
        iconColor: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        onTap: () => _openModule(AppModules.personal, 7),
      ));
    }

    if (_permissionService.canView(AppModules.invoices)) {
      items.add(_WorkspaceItem(
        title: 'Invoices & Billing',
        description: 'Quotations, bills & payment receipts',
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEF2F2),
        onTap: () => _openModule(AppModules.invoices, 2),
      ));
    }

    if (_permissionService.canView(AppModules.employees)) {
      items.add(_WorkspaceItem(
        title: 'Staff Directory',
        description: 'Team members & contact list',
        icon: Icons.badge_rounded,
        iconColor: const Color(0xFF06B6D4),
        bgColor: const Color(0xFFECFEFF),
        onTap: () => _openModule(AppModules.employees, 3),
      ));
    }

    if (_permissionService.canView(AppModules.ipc)) {
      items.add(_WorkspaceItem(
        title: 'IPC Valuations',
        description: 'Interim payment bills & BOQ claims',
        icon: Icons.request_quote_rounded,
        iconColor: const Color(0xFF0F766E),
        bgColor: const Color(0xFFF0FDFA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IpcListScreen()),
          );
        },
      ));
    }

    if (_permissionService.canView(AppModules.customers)) {
      items.add(_WorkspaceItem(
        title: 'Clients Directory',
        description: 'Client contacts, CR & VAT numbers',
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => _openModule(AppModules.customers, 8),
      ));
    }

    if (_permissionService.canView(AppModules.budget)) {
      items.add(_WorkspaceItem(
        title: 'Company Accounts',
        description: 'Financial allocations & budgets',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: () => _openModule(AppModules.budget, 5),
      ));
    }

    if (_permissionService.canView(AppModules.documentTemplates) || _permissionService.isAdmin) {
      items.add(_WorkspaceItem(
        title: 'Document Formats',
        description: 'Print designs, logo & signature',
        icon: Icons.print_rounded,
        iconColor: const Color(0xFF475569),
        bgColor: const Color(0xFFF8FAFC),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DocumentTemplateSettingsScreen()),
          );
        },
      ));
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No additional workspace modules are currently enabled for your role.\nPlease contact your Super Admin for access.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.bgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: item.iconColor, size: 20),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: Colors.grey[400], size: 16),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyTasksSection(BuildContext context) {
    if (_isLoadingTasks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_myTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Caught Up!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You have no pending task alerts assigned right now.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _myTasks.map((task) {
        final isCompleted = task.status.toLowerCase() == 'completed';
        final isOngoing = task.status.toLowerCase() == 'ongoing';

        Color statusBg = Colors.grey[100]!;
        Color statusColor = Colors.grey[800]!;
        if (isCompleted) {
          statusBg = const Color(0xFFE6F4EA);
          statusColor = const Color(0xFF137333);
        } else if (isOngoing) {
          statusBg = const Color(0xFFEFF6FF);
          statusColor = const Color(0xFF0B5ED7);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : isOngoing
                        ? Icons.play_circle_outline_rounded
                        : Icons.pending_actions_rounded,
                color: statusColor,
                size: 20,
              ),
            ),
            title: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey[500] : const Color(0xFF0A2540),
              ),
            ),
            subtitle: Text(
              task.siteName != null ? 'Site: ${task.siteName}' : (task.description ?? 'Project Task'),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            onTap: () {
              TaskDetailsSheet.show(
                context,
                task: task,
                onUpdated: _fetchMyTasks,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccessInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2540).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0A2540).withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0B5ED7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Role & Access Notice',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                ),
                const SizedBox(height: 3),
                Text(
                  'You are logged in as $_userName with assigned role "$_userRole". Financial overview metrics are restricted to administrators. Need extra permissions? Contact your system Super Admin.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
                    );
                  },
                  child: const Text(
                    'Manage My Account Profile →',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceItem {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  _WorkspaceItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });
}
