import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/dashboard_greeting_view.dart';
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
import '../../services/location_service.dart';
import '../../features/ai_assistant/widgets/floating_ai_assistant_button.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/document_templates/document_template_settings_screen.dart';
import '../../features/ipc/ipc_list_screen.dart';
import '../../features/reminders/reminders_screen.dart';

class _MainTabItem {
  final String key;
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const _MainTabItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _currentModule = AppModules.dashboard;
  final ApiService _apiService = ApiService();
  final _permissionService = PermissionService.instance;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);
  int _unreadChatCount = 0;
  RealtimeChannel? _unreadSubscription;

  @override
  void initState() {
    super.initState();
    _permissionService.loadUserPermissions();
    PresenceService.instance.initialize();
    LocationService.instance.initialize();
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

  void _navigateToModule(String moduleKey) {
    setState(() {
      _currentModule = moduleKey;
    });
  }

  void _navigateToTab(int index) {
    setState(() {
      switch (index) {
        case 0:
          _currentModule = AppModules.dashboard;
          break;
        case 1:
          _currentModule = AppModules.sites;
          break;
        case 2:
          _currentModule = AppModules.invoices;
          break;
        case 3:
          _currentModule = AppModules.employees;
          break;
        case 4:
          _currentModule = AppModules.chat;
          break;
        case 5:
          _currentModule = AppModules.budget;
          break;
        case 6:
          _currentModule = AppModules.products;
          break;
        case 7:
          _currentModule = AppModules.personal;
          break;
        case 8:
          _currentModule = AppModules.customers;
          break;
        default:
          _currentModule = AppModules.dashboard;
      }
    });
  }

  Widget _buildScreenForCurrentModule() {
    switch (_currentModule) {
      case AppModules.dashboard:
        return _permissionService.canView(AppModules.dashboard)
            ? const DashboardScreen()
            : DashboardGreetingView(
                onNavigateToTab: _navigateToTab,
                onNavigateToModule: _navigateToModule,
              );
      case AppModules.sites:
        return _permissionService.canView(AppModules.sites)
            ? const SiteListScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Sites Directory',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.invoices:
        return _permissionService.canView(AppModules.invoices)
            ? const InvoicesScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Invoices & Billing',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.employees:
        return _permissionService.canView(AppModules.employees)
            ? const EmployeeListScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Employees & Staff',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.chat:
        return _permissionService.canView(AppModules.chat)
            ? const ChatLayoutScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Team Chat',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.budget:
        return _permissionService.canView(AppModules.budget)
            ? const BudgetScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Accounts',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.products:
        return _permissionService.canView(AppModules.products)
            ? const ProductsScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Products Catalog',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.personal:
        return _permissionService.canView(AppModules.personal)
            ? const FoldersScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Personal Notes',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.reminders:
        return _permissionService.canView(AppModules.reminders)
            ? const RemindersScreen(showAppBar: false)
            : _AccessRestrictedView(
                moduleTitle: 'Reminders & Renewals',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
      case AppModules.customers:
        return _permissionService.canView(AppModules.customers)
            ? const CustomersScreen()
            : _AccessRestrictedView(
                moduleTitle: 'Customers Directory',
                onBackToDashboard: () => _navigateToModule(AppModules.dashboard),
              );
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
      isScrollControlled: true,
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

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

                  // Reminders & Renewals (Super Admin Only)
                  if (_permissionService.canAccessReminders) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notification_important_rounded, color: Color(0xFF0F4C81)),
                      ),
                      title: const Text('Reminders & Renewals', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Visa, passport, CPR & personal alerts for Super Admin'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RemindersScreen()),
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
                        _navigateToModule(AppModules.budget);
                      },
                    ),
                    const Divider(height: 1),
                  ],

                  // Option: Document & Print Formats (Logo, Seal, Signature, Template Settings)
                  if (_permissionService.canView(AppModules.documentTemplates) || _permissionService.isAdmin) ...[
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
                  ],

                  // Option: IPC (Interim Payment Certificate / Measurement Bill)
                  if (_permissionService.canView(AppModules.ipc)) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.request_quote_rounded, color: Color(0xFF0F766E)),
                      ),
                      title: const Text('IPC', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Client measurement bills, project BOQ quantities & valuations'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IpcListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],

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
                        _navigateToModule(AppModules.customers);
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
                        _navigateToModule(AppModules.products);
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
                        _navigateToModule(AppModules.personal);
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
                        PermissionService.instance.resetToGuest();
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
            ),
          ),
        );
      },
    );
  },
);
}

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _permissionService,
      builder: (context, _) {
        if (_permissionService.isLoading && _permissionService.permissions.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F9FD),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0B5ED7)),
            ),
          );
        }

        final List<_MainTabItem> tabItems = [
          const _MainTabItem(
            key: AppModules.dashboard,
            label: 'Dashboard',
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
          ),
          if (_permissionService.canView(AppModules.sites))
            const _MainTabItem(
              key: AppModules.sites,
              label: 'Sites',
              icon: Icon(Icons.business_outlined),
              selectedIcon: Icon(Icons.business_rounded),
            ),
          if (_permissionService.canView(AppModules.invoices))
            const _MainTabItem(
              key: AppModules.invoices,
              label: 'Invoice',
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
            ),
          if (_permissionService.canView(AppModules.employees))
            const _MainTabItem(
              key: AppModules.employees,
              label: 'Staff',
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
            ),
          if (_permissionService.canView(AppModules.chat))
            _MainTabItem(
              key: AppModules.chat,
              label: 'Chat',
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
            ),
          const _MainTabItem(
            key: 'more',
            label: 'More',
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
          ),
        ];

        int activeIndex = tabItems.indexWhere((t) => t.key == _currentModule);
        if (activeIndex == -1) {
          activeIndex = tabItems.indexWhere((t) => t.key == 'more');
        }
        if (activeIndex == -1) activeIndex = 0;

        return Scaffold(
          body: Stack(
            children: [
              _buildScreenForCurrentModule(),
              const FloatingAiAssistantButton(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: activeIndex,
            onDestinationSelected: (idx) {
              final selected = tabItems[idx];
              if (selected.key == 'more') {
                _showMoreBottomSheet();
              } else {
                setState(() {
                  _currentModule = selected.key;
                });
              }
            },
            destinations: tabItems.map((item) {
              return NavigationDestination(
                icon: item.icon,
                selectedIcon: item.selectedIcon,
                label: item.label,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _AccessRestrictedView extends StatelessWidget {
  final String moduleTitle;
  final VoidCallback? onBackToDashboard;

  const _AccessRestrictedView({
    required this.moduleTitle,
    this.onBackToDashboard,
  });

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
                  color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 54, color: Color(0xFF0B5ED7)),
              ),
              const SizedBox(height: 20),
              Text(
                'Access to $moduleTitle Restricted',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
              const SizedBox(height: 10),
              Text(
                'This module is not currently enabled for your assigned role (${PermissionService.instance.currentRole}).\n\nPlease contact a Super Admin if you need access to this section.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 24),
              if (onBackToDashboard != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2540),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onBackToDashboard,
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Back to Home Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
