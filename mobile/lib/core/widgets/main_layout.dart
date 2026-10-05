import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/sites/site_list_screen.dart';
import '../../features/employees/employee_list_screen.dart';
import '../../features/personal/folders_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/chat/chat_layout_screen.dart';
import '../../features/budget/budget_screen.dart';
import '../../features/roles/role_management_screen.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/services/presence_service.dart';
import '../../features/ai_assistant/widgets/floating_ai_assistant_button.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/document_templates/document_template_settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  final _permissionService = PermissionService.instance;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);
  int _unreadChatCount = 0;
  RealtimeChannel? _unreadSubscription;

  @override
  void initState() {
    super.initState();
    _permissionService.loadUserPermissions();
    _loadUnreadChatCount();
    _setupUnreadSubscription();
  }

  void _setupUnreadSubscription() {
    try {
      _unreadSubscription = Supabase.instance.client
          .channel('public:chat_messages_main')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_messages',
            callback: (_) => _loadUnreadChatCount(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _loadUnreadChatCount() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client
          .from('chat_messages')
          .select('id')
          .eq('receiver_id', uid)
          .eq('is_read', false);
      if (mounted) {
        setState(() {
          _unreadChatCount = (res as List).length;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_unreadSubscription != null) {
      Supabase.instance.client.removeChannel(_unreadSubscription!);
    }
    super.dispose();
  }

  Widget _buildScreenWithPermission(int index) {
    switch (index) {
      case 0:
        return _permissionService.canView(AppModules.dashboard)
            ? const DashboardScreen()
            : const _AccessRestrictedView(moduleTitle: 'Dashboard');
      case 1:
        return _permissionService.canView(AppModules.sites)
            ? const SiteListScreen()
            : const _AccessRestrictedView(moduleTitle: 'Sites Directory');
      case 2:
        return _permissionService.canView(AppModules.invoices)
            ? const InvoicesScreen()
            : const _AccessRestrictedView(moduleTitle: 'Invoices & Billing');
      case 3:
        return _permissionService.canView(AppModules.employees)
            ? const EmployeeListScreen()
            : const _AccessRestrictedView(moduleTitle: 'Employees & Staff');
      case 4:
        return _permissionService.canView(AppModules.chat)
            ? const ChatLayoutScreen()
            : const _AccessRestrictedView(moduleTitle: 'Team Chat');
      case 5:
        return _permissionService.canView(AppModules.budget)
            ? const BudgetScreen()
            : const _AccessRestrictedView(moduleTitle: 'Accounts');
      case 6:
        return _permissionService.canView(AppModules.products)
            ? const ProductsScreen()
            : const _AccessRestrictedView(moduleTitle: 'Products Catalog');
      case 7:
        return _permissionService.canView(AppModules.personal)
            ? const FoldersScreen()
            : const _AccessRestrictedView(moduleTitle: 'Personal Notes');
      case 8:
        return _permissionService.canView(AppModules.customers)
            ? const CustomersScreen()
            : const _AccessRestrictedView(moduleTitle: 'Customers Directory');
      default:
        return const DashboardScreen();
    }
  }

  void _showMoreBottomSheet() {
    final canViewBudget = _permissionService.canView(AppModules.budget);
    final canManageRoles = _permissionService.canView(AppModules.roleManagement) ||
        _permissionService.isAdmin;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return FutureBuilder(
          future: canViewBudget ? _apiService.getDashboardMetrics() : null,
          builder: (context, snapshot) {
            final metrics = snapshot.data;
            final remaining = metrics?.remainingBudget ?? 0.0;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'More Options & Controls',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _permissionService.currentRole.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B5ED7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Balance Overview Card in More (Guarded with permissions)
                  if (canViewBudget) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF0A3B66), Colors.blue[900]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'TOTAL REMAINING BALANCE',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currencyFormat.format(remaining),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Roles & Access Control (Admin / Super Admin)
                  if (canManageRoles) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8E24AA)),
                      ),
                      title: const Text('Roles & Access Control', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Configure Super Admin, Admin, Manager, & Custom roles'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RoleManagementScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Accounts (Company & Site Budgets)
                  if (canViewBudget) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
                      ),
                      title: const Text('Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Company & site budgets, income, expenses, and allocations'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => _currentIndex = 5);
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Document & Print Formats (Logo, Seal, Signature, Template Settings)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2540).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.print_rounded, color: Color(0xFF0A2540)),
                    ),
                    title: const Text('Document & Print Formats', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Company logo, seal, signature, address, and bill templates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DocumentTemplateSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // Option: Customers Directory
                  if (_permissionService.canView(AppModules.customers)) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2540).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.groups_rounded, color: Color(0xFF0A2540)),
                      ),
                      title: const Text('Customers Directory', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Manage clients, billing contacts, and VAT numbers'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => _currentIndex = 8);
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Products
                  if (_permissionService.canView(AppModules.products)) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0B5ED7)),
                      ),
                      title: const Text('Products & Materials', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Manage product inventory and prices'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => _currentIndex = 6);
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Personal Folders
                  if (_permissionService.canView(AppModules.personal)) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_shared_rounded, color: Colors.purple),
                      ),
                      title: const Text('Personal Folders & Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Private notes and workspace data'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => _currentIndex = 7);
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Account Sign Out
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.red),
                    ),
                    title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text('Log out of your account'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      try {
                        PresenceService.instance.dispose();
                        await Supabase.instance.client.auth.signOut();
                      } catch (e) {
                        debugPrint('Error during sign out: $e');
                      }
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayIndex = _currentIndex > 4 ? 5 : _currentIndex;

    return AnimatedBuilder(
      animation: _permissionService,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              _buildScreenWithPermission(_currentIndex),
              const FloatingAiAssistantButton(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: displayIndex,
            onDestinationSelected: (index) {
              if (index == 5) {
                _showMoreBottomSheet();
              } else {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business_rounded),
                label: 'Sites',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Invoice',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Staff',
              ),
              NavigationDestination(
                icon: _unreadChatCount > 0
                    ? Badge.count(
                        count: _unreadChatCount,
                        backgroundColor: const Color(0xFF25D366),
                        child: const Icon(Icons.chat_bubble_outline),
                      )
                    : const Icon(Icons.chat_bubble_outline),
                selectedIcon: _unreadChatCount > 0
                    ? Badge.count(
                        count: _unreadChatCount,
                        backgroundColor: const Color(0xFF25D366),
                        child: const Icon(Icons.chat_bubble_rounded),
                      )
                    : const Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccessRestrictedView extends StatelessWidget {
  final String moduleTitle;
  const _AccessRestrictedView({required this.moduleTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(moduleTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person_rounded, size: 54, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Access to $moduleTitle Restricted',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
              const SizedBox(height: 10),
              Text(
                'Your current assigned role (${PermissionService.instance.currentRole}) does not have permission to access this module.\n\nPlease contact a Super Admin or Admin to request access permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
