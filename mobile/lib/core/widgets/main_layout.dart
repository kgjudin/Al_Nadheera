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
import '../../services/api_service.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/services/presence_service.dart';
import '../../features/ai_assistant/widgets/floating_ai_assistant_button.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 0);
  int _unreadChatCount = 0;
  RealtimeChannel? _unreadSubscription;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SiteListScreen(),
    const EmployeeListScreen(),
    const BudgetScreen(),
    const ChatLayoutScreen(),
    const ProductsScreen(), // Index 5: Products
    const FoldersScreen(),  // Index 6: Personal
  ];

  @override
  void initState() {
    super.initState();
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

  void _showMoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return FutureBuilder(
          future: _apiService.getDashboardMetrics(),
          builder: (context, snapshot) {
            final metrics = snapshot.data;
            final remaining = metrics?.remainingBudget ?? 0.0;
            final assigned = metrics?.totalAssignedBudget ?? 0.0;
            final spent = metrics?.totalSpent ?? 0.0;

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
                  const Text(
                    'More Options & Financial Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  const SizedBox(height: 14),

                  // Balance Overview Card in More
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
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Assigned: ${currencyFormat.format(assigned)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('Spent: ${currencyFormat.format(spent)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Option 1: Products
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
                      setState(() => _currentIndex = 5);
                    },
                  ),
                  const Divider(height: 1),

                  // Option 2: Personal Folders
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
                      setState(() => _currentIndex = 6);
                    },
                  ),
                  const Divider(height: 1),

                  // Option 3: Account Sign Out
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
    // If _currentIndex is 5 or 6 (Products or Personal opened via More), show those screens
    final displayIndex = _currentIndex > 4 ? 4 : _currentIndex;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
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
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business_rounded),
            label: 'Sites',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Staff',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budget',
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
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
