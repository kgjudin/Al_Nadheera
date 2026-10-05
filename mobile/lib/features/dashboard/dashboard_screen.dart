import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../models/dashboard_metrics_model.dart';
import '../../models/site_model.dart';
import '../sites/site_list_screen.dart';
import '../sites/site_details_screen.dart';
import '../employees/employee_list_screen.dart';
import '../chat/chat_layout_screen.dart';
import '../roles/role_management_screen.dart';
import '../profile/profile_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  final _permissionService = PermissionService.instance;

  late Future<DashboardMetrics> _metricsFuture;
  List<Map<String, dynamic>> _teamMembers = [];
  List<Site> _recentSites = [];

  String _userName = 'Judin KG';
  String _userRole = 'Super Admin';
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _metricsFuture = _fetchMetrics();
    });
    _fetchRecentSitesAndTeam();
  }

  Future<void> _loadUserInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('employees')
          .select('name, role, profile_image_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (res != null) {
            _userName = res['name']?.toString() ?? 'Judin KG';
            _userRole = res['role']?.toString() ?? _permissionService.currentRole;
            _userAvatarUrl = res['profile_image_url']?.toString();
          } else {
            _userName = user.userMetadata?['name']?.toString() ?? 'Judin KG';
            _userRole = user.userMetadata?['role']?.toString() ?? _permissionService.currentRole;
            _userAvatarUrl = user.userMetadata?['avatar_url']?.toString();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userRole = _permissionService.currentRole;
        });
      }
    }
  }

  Future<DashboardMetrics> _fetchMetrics() async {
    try {
      return await _apiService.getDashboardMetrics();
    } catch (_) {
      final sitesRes = await _supabase.from('sites').select('id, status');
      final empsRes = await _supabase.from('employees').select('id');

      final sList = (sitesRes as List?) ?? [];
      final totalSites = sList.length;
      final activeSites = sList.where((s) => s['status'] == 'Active').length;
      final totalEmployees = (empsRes as List?)?.length ?? 0;

      return DashboardMetrics(
        totalSites: totalSites > 0 ? totalSites : 2,
        activeSites: activeSites > 0 ? activeSites : 2,
        totalEmployees: totalEmployees > 0 ? totalEmployees : 6,
        totalAssignedBudget: 0,
        totalSpent: 0,
        remainingBudget: 0,
        recentSites: [],
      );
    }
  }

  Future<void> _fetchRecentSitesAndTeam() async {
    try {
      // 1. Fetch sites
      final sitesData = await _supabase.from('sites').select('*').order('created_at', ascending: false).limit(5);
      final sites = (sitesData as List).map((json) => Site.fromJson(json)).toList();

      // 2. Fetch employees
      final empsData = await _supabase.from('employees').select('*').order('created_at', ascending: false).limit(6);
      final emps = List<Map<String, dynamic>>.from(empsData);

      if (mounted) {
        setState(() {
          _recentSites = sites;
          _teamMembers = emps;
        });
      }
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'GOOD MORNING';
    if (hour >= 12 && hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _metricsFuture;
          },
          child: FutureBuilder<DashboardMetrics>(
            future: _metricsFuture,
            builder: (context, snapshot) {
              final metrics = snapshot.data ??
                  DashboardMetrics(
                    totalSites: 2,
                    activeSites: 2,
                    totalEmployees: 6,
                    totalAssignedBudget: 0,
                    totalSpent: 0,
                    remainingBudget: 0,
                    recentSites: [],
                  );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final isMedium = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // 1. TOP APP BAR (Search, Branding, Theme, Notifications, Profile)
                      _buildTopHeaderBar(context),

                      const SizedBox(height: 20),

                      // 2. HERO GREETING BANNER
                      _buildHeroBanner(formattedDate),

                      const SizedBox(height: 24),

                      // 3. KEY OVERVIEW SECTION HEADER
                      _buildSectionHeaderWithLivePill('Key Overview'),

                      const SizedBox(height: 14),

                      // 4. STAT CARDS (Total Sites, Active Sites, Employees, Access Control)
                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildTotalSitesCard(metrics)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildActiveSitesCard(metrics)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildEmployeesCard(metrics)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildAccessControlCard()),
                          ],
                        )
                      else if (isMedium)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildTotalSitesCard(metrics)),
                                const SizedBox(width: 14),
                                Expanded(child: _buildActiveSitesCard(metrics)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: _buildEmployeesCard(metrics)),
                                const SizedBox(width: 14),
                                Expanded(child: _buildAccessControlCard()),
                              ],
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildTotalSitesCard(metrics)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildActiveSitesCard(metrics)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildEmployeesCard(metrics)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildAccessControlCard()),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 28),

                      // 5. QUICK SHORTCUTS HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quick Shortcuts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F2537),
                            ),
                          ),
                          Text(
                            'Access your most used features',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 6. QUICK SHORTCUTS 4 TILES
                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildShortcutAllSites()),
                            const SizedBox(width: 14),
                            Expanded(child: _buildShortcutStaffDirectory()),
                            const SizedBox(width: 14),
                            Expanded(child: _buildShortcutTeamChat()),
                            const SizedBox(width: 14),
                            Expanded(child: _buildShortcutAccessControl()),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildShortcutAllSites()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildShortcutStaffDirectory()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildShortcutTeamChat()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildShortcutAccessControl()),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 30),

                      // 7. BOTTOM TWO SECTIONS (Recent Projects & Team Members)
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildRecentProjectsCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTeamMembersCard()),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildRecentProjectsCard(),
                            const SizedBox(height: 18),
                            _buildTeamMembersCard(),
                          ],
                        ),

                      const SizedBox(height: 40),

                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // --- 1. TOP BAR ---
  Widget _buildTopHeaderBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo & Name
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B5ED7), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B5ED7).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AL NADHEERA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      Text(
                        'TRADING',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF0B5ED7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Right Actions: Notifications & Avatar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, size: 19, color: Color(0xFF4B5563)),
                          padding: EdgeInsets.zero,
                          onPressed: () {},
                        ),
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
                      ).then((_) => _loadUserInfo());
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0B5ED7).withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF0B5ED7),
                        backgroundImage: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty ? NetworkImage(_userAvatarUrl!) : null,
                        child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty)
                            ? Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mobile Touch Search Bar
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 19, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search sites, employees, materials...',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Wide / Tablet / Desktop Top Bar
    return Row(
      children: [
        // Brand Logo
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0B5ED7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AL NADHEERA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF0A2540),
                  ),
                ),
                Text(
                  'TRADING',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF0B5ED7),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(width: 14),

        // Search Bar with Ctrl + K
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search anything...',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Ctrl + K',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Sun / Theme icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            icon: const Icon(Icons.wb_sunny_outlined, size: 18, color: Color(0xFF4B5563)),
            padding: EdgeInsets.zero,
            onPressed: () {},
          ),
        ),

        const SizedBox(width: 8),

        // Notification Bell with badge 3
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 19, color: Color(0xFF4B5563)),
                padding: EdgeInsets.zero,
                onPressed: () {},
              ),
            ),
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 12),

        // User Avatar + Role
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
            ).then((_) => _loadUserInfo());
          },
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF0B5ED7),
                backgroundImage: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty ? NetworkImage(_userAvatarUrl!) : null,
                child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty)
                    ? Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'J',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  ),
                  Text(
                    _userRole,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. HERO BANNER ---
  Widget _buildHeroBanner(String formattedDate) {
    final hour = DateTime.now().hour;
    final greetingIcon = hour < 12
        ? Icons.wb_sunny_rounded
        : hour < 17
            ? Icons.light_mode_rounded
            : Icons.nightlight_round;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEBF3FD),
            Color(0xFFF3F7FE),
            Color(0xFFE9F1FC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6E4F8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B5ED7).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Subtle, elegant background architectural watermark (won't collide with text)
            Positioned(
              right: -15,
              bottom: -15,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.07,
                  child: const Icon(
                    Icons.apartment_rounded,
                    size: 150,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 85,
              bottom: -25,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.04,
                  child: const Icon(
                    Icons.domain_rounded,
                    size: 110,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            // Soft radiant glow in top right
            Positioned(
              top: -40,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF60A5FA).withValues(alpha: 0.22),
                        const Color(0xFF60A5FA).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Banner Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Greeting Pill on left + Chic Slogan Tag on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Greeting Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(greetingIcon, color: const Color(0xFFF59E0B), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Elegant Motto Pill: BUILD • MANAGE • GROW
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE).withValues(alpha: 0.7)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'BUILD',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: Text('•', style: TextStyle(fontSize: 8, color: Color(0xFF93C5FD))),
                            ),
                            Text(
                              'MANAGE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: Text('•', style: TextStyle(fontSize: 8, color: Color(0xFF93C5FD))),
                            ),
                            Text(
                              'GROW',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Welcome Headline
                  RichText(
                    text: TextSpan(
                      text: 'Welcome back,\n',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(
                          text: '$_userRole!',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Here's what's happening with AL NADHEERA today.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date chip & Systems Online
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'All Systems Online',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. SECTION HEADER ---
  Widget _buildSectionHeaderWithLivePill(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F2537),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNarrow) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Live Updates',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_rounded, size: 11, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- 4. THE 4 STAT CARDS ---
  // Card 1: Total Sites
  Widget _buildTotalSitesCard(DashboardMetrics metrics) {
    return _buildSparklineCard(
      title: 'Total Sites',
      subtitle: 'Registered Projects',
      value: metrics.totalSites.toString(),
      trend: '↑ 12%',
      trendColor: const Color(0xFF10B981),
      icon: Icons.apartment_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBgColor: const Color(0xFFDBEAFE),
      cardBgColor: const Color(0xFFF1F6FF),
      borderColor: const Color(0xFFDBEAFE),
      sparklineColor: const Color(0xFF2563EB),
      sparklineValues: [1.0, 1.2, 1.1, 1.5, 1.4, 1.8, 2.0],
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SiteListScreen()));
      },
    );
  }

  // Card 2: Active Sites
  Widget _buildActiveSitesCard(DashboardMetrics metrics) {
    return _buildSparklineCard(
      title: 'Active Sites',
      subtitle: 'Currently Under Execution',
      value: metrics.activeSites.toString(),
      trend: '↑ 0%',
      trendColor: const Color(0xFF10B981),
      icon: Icons.construction_rounded,
      iconColor: const Color(0xFF059669),
      iconBgColor: const Color(0xFFD1FAE5),
      cardBgColor: const Color(0xFFF0FDF4),
      borderColor: const Color(0xFFDCFCE7),
      sparklineColor: const Color(0xFF10B981),
      sparklineValues: [1.0, 1.3, 1.2, 1.6, 1.5, 1.9, 2.0],
      hasLiveBadge: true,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SiteListScreen()));
      },
    );
  }

  // Card 3: Employees
  Widget _buildEmployeesCard(DashboardMetrics metrics) {
    return _buildSparklineCard(
      title: 'Employees',
      subtitle: 'Staff & Team Directory',
      value: metrics.totalEmployees.toString(),
      trend: '↑ 18%',
      trendColor: const Color(0xFF10B981),
      icon: Icons.groups_rounded,
      iconColor: const Color(0xFF8B5CF6),
      iconBgColor: const Color(0xFFEDE9FE),
      cardBgColor: const Color(0xFFFAF5FF),
      borderColor: const Color(0xFFF3E8FF),
      sparklineColor: const Color(0xFF8B5CF6),
      sparklineValues: [3.0, 4.0, 4.2, 5.0, 4.8, 5.6, 6.0],
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
      },
    );
  }

  // Card 4: Access Control
  Widget _buildAccessControlCard() {
    return _buildSparklineCard(
      title: 'Access Control',
      subtitle: 'Manage Roles',
      value: '—',
      trend: '',
      trendColor: Colors.transparent,
      icon: Icons.security_rounded,
      iconColor: const Color(0xFFF59E0B),
      iconBgColor: const Color(0xFFFEF3C7),
      cardBgColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFEF3C7),
      sparklineColor: const Color(0xFFF59E0B),
      sparklineValues: [1.0, 1.5, 2.0, 1.8, 2.3, 2.1, 2.5],
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleManagementScreen()));
      },
    );
  }

  Widget _buildSparklineCard({
    required String title,
    required String subtitle,
    required String value,
    required String trend,
    required Color trendColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color cardBgColor,
    required Color borderColor,
    required Color sparklineColor,
    required List<double> sparklineValues,
    required VoidCallback onTap,
    bool hasLiveBadge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: sparklineColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with Icon & Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F2537),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasLiveBadge) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '• Live',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Number & Sparkline Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F2537),
                            height: 1.1,
                          ),
                        ),
                        if (trend.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            trend,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Smooth wave sparkline
                    SizedBox(
                      width: 70,
                      height: 34,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          color: sparklineColor,
                          values: sparklineValues,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. QUICK SHORTCUTS ---
  Widget _buildShortcutAllSites() {
    return _buildShortcutCard(
      title: 'All Sites',
      subtitle: 'View all projects',
      icon: Icons.apartment_rounded,
      bgColor: const Color(0xFFEBF3FF),
      iconColor: Colors.white,
      iconContainerColor: const Color(0xFF2563EB),
      arrowColor: const Color(0xFF2563EB),
      arrowBgColor: const Color(0xFFDBEAFE),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SiteListScreen()));
      },
    );
  }

  Widget _buildShortcutStaffDirectory() {
    return _buildShortcutCard(
      title: 'Staff Directory',
      subtitle: 'Team members',
      icon: Icons.badge_rounded,
      bgColor: const Color(0xFFEBFDF4),
      iconColor: Colors.white,
      iconContainerColor: const Color(0xFF059669),
      arrowColor: const Color(0xFF059669),
      arrowBgColor: const Color(0xFFD1FAE5),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
      },
    );
  }

  Widget _buildShortcutTeamChat() {
    return _buildShortcutCard(
      title: 'Team Chat',
      subtitle: 'Project messages',
      icon: Icons.chat_bubble_rounded,
      bgColor: const Color(0xFFF7F2FE),
      iconColor: Colors.white,
      iconContainerColor: const Color(0xFF8B5CF6),
      arrowColor: const Color(0xFF8B5CF6),
      arrowBgColor: const Color(0xFFEDE9FE),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatLayoutScreen()));
      },
    );
  }

  Widget _buildShortcutAccessControl() {
    return _buildShortcutCard(
      title: 'Access Control',
      subtitle: 'Manage roles',
      icon: Icons.lock_rounded,
      bgColor: const Color(0xFFFFF9EE),
      iconColor: Colors.white,
      iconContainerColor: const Color(0xFFF59E0B),
      arrowColor: const Color(0xFFF59E0B),
      arrowBgColor: const Color(0xFFFEF3C7),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleManagementScreen()));
      },
    );
  }

  Widget _buildShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required Color iconContainerColor,
    required Color arrowColor,
    required Color arrowBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: arrowBgColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2537),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: arrowBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.arrow_forward_rounded, color: arrowColor, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 7. BOTTOM THREE CARDS ---
  // Panel 1: Recent Projects / Sites
  Widget _buildRecentProjectsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Projects / Sites',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SiteListScreen()));
                },
                child: const Row(
                  children: [
                    Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sites list
          if (_recentSites.isEmpty) ...[
            // Default reference items from mockup
            _buildProjectTile(
              title: 'Site A – Residential Complex',
              status: 'Active',
              statusColor: const Color(0xFF10B981),
              statusBgColor: const Color(0xFFD1FAE5),
              location: 'Kozhikode, Kerala',
              progress: 0.75,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SiteListScreen())),
            ),
            const Divider(height: 20),
            _buildProjectTile(
              title: 'Site B – Commercial Building',
              status: 'In Progress',
              statusColor: const Color(0xFF2563EB),
              statusBgColor: const Color(0xFFDBEAFE),
              location: 'Calicut, Kerala',
              progress: 0.50,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SiteListScreen())),
            ),
          ] else ...[
            ..._recentSites.take(3).map((site) {
              final isActive = site.status == 'Active';
              return Column(
                children: [
                  _buildProjectTile(
                    title: site.name,
                    status: site.status,
                    statusColor: isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    statusBgColor: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
                    location: site.location ?? 'Kerala, India',
                    progress: 0.70,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SiteDetailsScreen(siteId: site.id, initialSite: site)),
                      );
                    },
                  ),
                  const Divider(height: 20),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectTile({
    required String title,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required String location,
    required double progress,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Building Image Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFFE2E8F0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Icon(Icons.apartment_rounded, color: Color(0xFF64748B), size: 30),
                  Container(color: Colors.blue.withValues(alpha: 0.05)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  // Panel 2: Team Members
  Widget _buildTeamMembersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
                },
                child: const Row(
                  children: [
                    Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_teamMembers.isEmpty) ...[
            // Default members from mockup
            _buildMemberRow('Vyshag', 'Video Grapher', 'Online', const Color(0xFF10B981)),
            const SizedBox(height: 10),
            _buildMemberRow('Adarsh', 'Video Editor', 'Online', const Color(0xFF10B981)),
            const SizedBox(height: 10),
            _buildMemberRow('Sanal', 'Digital Marketing', 'Away', const Color(0xFFF59E0B)),
            const SizedBox(height: 10),
            _buildMemberRow('Anwar Sadik', 'CMO', 'Online', const Color(0xFF10B981)),
            const SizedBox(height: 10),
            _buildMemberRow('Thejus', 'HR Department', 'Offline', const Color(0xFF6B7280)),
          ] else ...[
            ..._teamMembers.take(5).map((m) {
              final name = m['name']?.toString() ?? 'Team Member';
              final role = m['role']?.toString() ?? 'Staff';
              final isOnline = m['is_online'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildMemberRow(
                  name,
                  role,
                  isOnline ? 'Online' : 'Offline',
                  isOnline ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                  imageUrl: m['profile_image_url']?.toString(),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(String name, String role, String status, Color statusColor, {String? imageUrl}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFF0B5ED7).withValues(alpha: 0.15),
          backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: (imageUrl == null || imageUrl.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B5ED7)),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2537)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                role,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.more_horiz_rounded, size: 16, color: Colors.grey),
      ],
    );
  }
}

// Sparkline Custom Painter for smooth Bézier wave charts
class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> values;

  _SparklinePainter({required this.color, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    double getY(double val) {
      final normalized = (val - minVal) / range;
      return size.height - (normalized * (size.height - 8)) - 4;
    }

    path.moveTo(0, getY(values[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(values[0]));

    for (int i = 1; i < values.length; i++) {
      final p0X = (i - 1) * stepX;
      final p0Y = getY(values[i - 1]);
      final p1X = i * stepX;
      final p1Y = getY(values[i]);

      final cX1 = p0X + (p1X - p0X) / 2;
      final cY1 = p0Y;
      final cX2 = p0X + (p1X - p0X) / 2;
      final cY2 = p1Y;

      path.cubicTo(cX1, cY1, cX2, cY2, p1X, p1Y);
      fillPath.cubicTo(cX1, cY1, cX2, cY2, p1X, p1Y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => false;
}
