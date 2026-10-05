import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';
import '../../models/site_model.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'summary/site_summary_tab.dart';
import 'budget/site_budget_tab.dart';
import 'labour/site_labour_tab.dart';
import 'materials/site_material_tab.dart';
import 'subcontractors/site_subcontractor_tab.dart';
import 'additional_expenses/site_additional_expense_tab.dart';
import 'tasks/site_tasks_tab.dart';
import 'chat/site_chat_screen.dart';
import 'add_edit_site_screen.dart';

class _SiteTabDefinition {
  final String key;
  final String title;
  final IconData icon;
  final Widget Function(int refreshCount) builder;

  const _SiteTabDefinition({
    required this.key,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

class SiteDetailsScreen extends StatefulWidget {
  final String siteId;
  final Site? initialSite;

  const SiteDetailsScreen({super.key, required this.siteId, this.initialSite});

  @override
  State<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends State<SiteDetailsScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  final _permissionService = PermissionService.instance;

  late Future<Site> _siteFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 2);
  final dateFormat = DateFormat('yyyy-MM-dd');

  TabController? _tabController;
  List<_SiteTabDefinition> _accessibleTabs = [];
  final Map<String, int> _tabRefreshCounts = {};
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _permissionService.addListener(_onPermissionsChanged);
    _setupTabs();
    _loadSite();
  }

  void _onPermissionsChanged() {
    if (mounted) {
      setState(() {
        _setupTabs();
      });
    }
  }

  void _setupTabs() {
    final allDefs = <_SiteTabDefinition>[
      _SiteTabDefinition(
        key: AppModules.siteSummary,
        title: 'Summary',
        icon: Icons.assessment_outlined,
        builder: (refreshCount) => SiteSummaryTab(
          key: ValueKey('summary_$refreshCount'),
          siteId: widget.siteId,
          onDataChanged: _loadSite,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteTasks,
        title: 'Tasks',
        icon: Icons.check_box_outlined,
        builder: (refreshCount) => SiteTasksTab(
          key: ValueKey('tasks_$refreshCount'),
          siteId: widget.siteId,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteLabour,
        title: 'Labour',
        icon: Icons.engineering_outlined,
        builder: (refreshCount) => SiteLabourTab(
          key: ValueKey('labour_$refreshCount'),
          siteId: widget.siteId,
          onDataChanged: _loadSite,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteMaterials,
        title: 'Materials',
        icon: Icons.inventory_outlined,
        builder: (refreshCount) => SiteMaterialTab(
          key: ValueKey('material_$refreshCount'),
          siteId: widget.siteId,
          onDataChanged: _loadSite,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteSubcontractors,
        title: 'Sub-Contractors',
        icon: Icons.handshake_outlined,
        builder: (refreshCount) => SiteSubcontractorTab(
          key: ValueKey('subcontractors_$refreshCount'),
          siteId: widget.siteId,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteAdditionalExpenses,
        title: 'Additional',
        icon: Icons.receipt_long_outlined,
        builder: (refreshCount) => SiteAdditionalExpenseTab(
          key: ValueKey('additional_$refreshCount'),
          siteId: widget.siteId,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteBudget,
        title: 'Budget',
        icon: Icons.account_balance_wallet_outlined,
        builder: (refreshCount) => SiteBudgetTab(
          key: ValueKey('budget_$refreshCount'),
          siteId: widget.siteId,
        ),
      ),
    ];

    final filtered = allDefs.where((tab) => _permissionService.canView(tab.key)).toList();

    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();

    _accessibleTabs = filtered;
    for (final t in _accessibleTabs) {
      _tabRefreshCounts.putIfAbsent(t.key, () => 0);
    }

    if (_accessibleTabs.isNotEmpty) {
      _tabController = TabController(length: _accessibleTabs.length, vsync: this);
      _tabController!.addListener(_handleTabChange);
      _lastTabIndex = 0;
    } else {
      _tabController = null;
    }
  }

  @override
  void dispose() {
    _permissionService.removeListener(_onPermissionsChanged);
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController != null && !_tabController!.indexIsChanging && _tabController!.index != _lastTabIndex) {
      _lastTabIndex = _tabController!.index;
      _triggerTabRefresh(_lastTabIndex);
    }
  }

  void _triggerTabRefresh(int index) {
    if (index >= 0 && index < _accessibleTabs.length) {
      final tabKey = _accessibleTabs[index].key;
      setState(() {
        _tabRefreshCounts[tabKey] = (_tabRefreshCounts[tabKey] ?? 0) + 1;
      });
      _loadSite();
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  void _loadSite() {
    setState(() {
      _siteFuture = _fetchLiveSiteData();
    });
  }

  Future<Site> _fetchLiveSiteData() async {
    final baseSite = await _apiService.getSite(widget.siteId).catchError((_) {
      if (widget.initialSite != null) return widget.initialSite!;
      return Site(id: widget.siteId, name: 'Project Site', status: 'Active', assignedBudget: 0);
    });

    try {
      final summaries = await _supabase.from('site_summary').select('received_amount, cash_expenses').eq('site_id', widget.siteId);

      double receivedSum = 0.0;
      double spentSum = 0.0;

      for (var s in (summaries as List)) {
        receivedSum += _toDouble(s['received_amount']);
        spentSum += _toDouble(s['cash_expenses']);
      }

      return Site(
        id: baseSite.id,
        name: baseSite.name,
        code: baseSite.code,
        clientName: baseSite.clientName,
        location: baseSite.location,
        startDate: baseSite.startDate,
        status: baseSite.status,
        assignedBudget: baseSite.assignedBudget,
        spent: spentSum,
        receivedSummary: receivedSum,
        createdAt: baseSite.createdAt,
        updatedAt: baseSite.updatedAt,
      );
    } catch (_) {
      return baseSite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canChat = _permissionService.canView(AppModules.siteChat);
    final canEditSite = _permissionService.canEdit(AppModules.siteEdit);
    final canViewFinancials = _permissionService.canView(AppModules.siteBudget) ||
        _permissionService.canView(AppModules.siteSummary);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0A2540),
        title: const Text('Site Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (canChat)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0B5ED7)),
              tooltip: 'Site Chat',
              onPressed: () async {
                final nav = Navigator.of(context);
                final site = await _siteFuture.catchError((_) => widget.initialSite!);
                if (mounted) {
                  nav.push(
                    MaterialPageRoute(
                      builder: (context) => SiteChatScreen(
                        siteId: widget.siteId,
                        siteName: site.name,
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<Site>(
        future: _siteFuture,
        builder: (context, snapshot) {
          final site = snapshot.data ?? widget.initialSite;
          final isLiveActive = site?.status == 'Active';

          return Column(
            children: [
              // Top Executive Site Header Banner
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2540),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Site Title & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (site?.code != null && site!.code!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          site.code!,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    const Text(
                                      'PROJECT DETAILS',
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  site?.name ?? 'Loading Site...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isLiveActive ? const Color(0xFFE6F4EA) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isLiveActive ? const Color(0xFF00C853) : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (site?.status ?? 'Active').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isLiveActive ? const Color(0xFF137333) : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canEditSite) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                  tooltip: 'Edit Site Info',
                                  onPressed: () {
                                    if (site != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddEditSiteScreen(site: site),
                                        ),
                                      ).then((_) => _loadSite());
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lead / Client & Location Row
                      if (site != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  site.clientName != null && site.clientName!.isNotEmpty ? site.clientName![0].toUpperCase() : 'S',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Client: ${site.clientName ?? 'N/A'}  •  Location: ${site.location ?? 'N/A'}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Financial Metric Bar (Guarded with permissions)
                      if (canViewFinancials) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Assigned Budget',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(site?.assignedBudget ?? 0),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Total Spend', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(site?.spent ?? 0),
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Remaining Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format((site?.assignedBudget ?? 0) - (site?.spent ?? 0)),
                                  style: TextStyle(
                                    color: ((site?.assignedBudget ?? 0) - (site?.spent ?? 0)) < 0 ? Colors.redAccent : Colors.greenAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Started: ${site?.startDate != null ? dateFormat.format(site!.startDate!) : 'N/A'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Role Restricted View',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Dynamic Tab Bar & View
              if (_accessibleTabs.isEmpty) ...[
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_person_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 14),
                          Text(
                            'No Site Modules Permitted',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your role or employee account has not been granted access to any sub-options for this site. Contact an administrator for access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Styled Pill Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF0B5ED7),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFF0B5ED7),
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    onTap: (index) {
                      _lastTabIndex = index;
                      _triggerTabRefresh(index);
                    },
                    tabs: _accessibleTabs.map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.title)).toList(),
                  ),
                ),

                // Tab Contents View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _accessibleTabs.map((t) {
                      final refreshCount = _tabRefreshCounts[t.key] ?? 0;
                      return t.builder(refreshCount);
                    }).toList(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
