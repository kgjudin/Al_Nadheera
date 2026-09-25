import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../models/dashboard_metrics_model.dart';
import '../../models/site_model.dart';
import '../sites/site_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  late Future<DashboardMetrics> _dashboardFuture;
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dashboardFuture = _apiService.getDashboardMetrics();
    });
  }

  String _getUserDisplayName() {
    final user = _supabase.auth.currentUser;
    if (user?.userMetadata != null && user!.userMetadata!['full_name'] != null) {
      return user.userMetadata!['full_name'];
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      final namePart = user.email!.split('@').first;
      return namePart[0].toUpperCase() + namePart.substring(1);
    }
    return 'Alex';
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('MMM dd').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _dashboardFuture;
          },
          child: FutureBuilder<DashboardMetrics>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final metrics = snapshot.data ??
                  DashboardMetrics(
                    totalSites: 0,
                    activeSites: 0,
                    totalEmployees: 0,
                    totalAssignedBudget: 0,
                    totalSpent: 0,
                    remainingBudget: 0,
                    recentSites: [],
                  );

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                children: [
                  // --- TOP HEADER BAR ---
                  _buildHeaderBar(todayStr),

                  const SizedBox(height: 20),

                  // --- METRICS ROW (3 Cards) ---
                  _buildTopMetricsRow(metrics),

                  const SizedBox(height: 20),

                  // --- OVERALL BUDGET CARD ---
                  _buildOverallBudgetCard(metrics),

                  const SizedBox(height: 24),

                  // --- RECENT SITES HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Sites',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F2537),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active projects under executive supervision',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SiteListScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              'View All (${metrics.totalSites})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B5ED7),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF0B5ED7)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // --- RECENT SITES LIST ---
                  if (metrics.recentSites.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'No active sites found.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...metrics.recentSites.map((site) => _buildRecentSiteCard(site)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Header Bar with Greeting, Refresh, Notifications, Avatar
  Widget _buildHeaderBar(String todayStr) {
    final userName = _getUserDisplayName();
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• $todayStr • LIVE PORTFOLIO',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8FA0B5),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Good morning, $userName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A2540),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Executive Operations Hub',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),

        // Action Icons (Refresh, Bell, Avatar)
        Row(
          children: [
            // Refresh Button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0A2540)),
                onPressed: _loadData,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 10),

            // Notification Bell Button
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF0A2540)),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Avatar Badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0A3B66),
                  child: Text(
                    firstLetter,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Top Metrics Row (Total Sites, Active Site, Employees)
  Widget _buildTopMetricsRow(DashboardMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.domain_outlined,
            iconBg: const Color(0xFFE8F1FF),
            iconColor: const Color(0xFF1E6091),
            badgeText: '+1 New',
            badgeBg: const Color(0xFFE6F4EA),
            badgeTextColor: const Color(0xFF137333),
            value: metrics.totalSites.toString(),
            label: 'Total Sites',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.check_circle_outline_rounded,
            iconBg: const Color(0xFFE6F4EA),
            iconColor: const Color(0xFF137333),
            badgeText: '•',
            badgeBg: const Color(0xFF00C853),
            badgeTextColor: Colors.white,
            isDotBadge: true,
            value: metrics.activeSites.toString(),
            label: 'Active Site',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.people_outline_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7E22CE),
            badgeText: 'On Duty',
            badgeBg: const Color(0xFFF1F5F9),
            badgeTextColor: const Color(0xFF475569),
            value: metrics.totalEmployees.toString(),
            label: 'Employees',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    bool isDotBadge = false,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (isDotBadge)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2540),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Overall Budget Card
  Widget _buildOverallBudgetCard(DashboardMetrics metrics) {
    final assigned = metrics.totalAssignedBudget;
    final spent = metrics.totalSpent;
    final remaining = metrics.remainingBudget;

    final spentPct = assigned > 0 ? ((spent / assigned) * 100).toStringAsFixed(1) : '0.0';
    final remainingPct = assigned > 0 ? (((remaining) / assigned) * 100).clamp(0, 100).toStringAsFixed(0) : '100';

    final progressVal = assigned > 0 ? (spent / assigned).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C853),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Overall Budget',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FY24',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text('Q4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Year', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3 Columns: ASSIGNED, SPENT, REMAINING
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ASSIGNED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(assigned),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('QAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(spent),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  const SizedBox(height: 2),
                  Text('$spentPct% used', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('REMAINING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(remaining),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$remainingPct% left',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Budget Utilization progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budget Utilization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              Text(
                '• Optimal ($spentPct%)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressVal,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF00C853),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Bottom card row: Capital safe & Full Breakdown >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Capital safe', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              InkWell(
                onTap: () {
                  // Navigate to Budget screen
                },
                child: const Row(
                  children: [
                    Text(
                      'Full Breakdown',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: Color(0xFF0A2540)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Recent Site Card
  Widget _buildRecentSiteCard(Site site) {
    final spent = site.spent;
    final remaining = site.assignedBudget - spent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Expanded(
                child: Text(
                  site.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      site.status.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${site.code ?? 'BH001'} Civil & Commercial',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),

          // Lead Info Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    site.clientName != null && site.clientName!.isNotEmpty ? site.clientName![0].toUpperCase() : 'J',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lead: ${site.clientName ?? 'Judin'}  •  ${site.location ?? 'Manama, Bahrain'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // BUDGET, SPENT, REMAINING
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BUDGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(site.assignedBudget),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('SPENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(
                    '${currencyFormat.format(spent)} QAR',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('REMAINING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(remaining),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS 0%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5),
              ),
              InkWell(
                onTap: () {
                  // Navigate to site details
                },
                child: const Row(
                  children: [
                    Text(
                      'Manage Site',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B5ED7)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: Color(0xFF0B5ED7)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
