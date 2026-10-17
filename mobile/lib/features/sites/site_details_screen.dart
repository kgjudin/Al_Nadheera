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
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final dateFormat = DateFormat('yyyy-MM-dd');

  TabController? _tabController;
  List<_SiteTabDefinition> _accessibleTabs = [];
  final Map<String, int> _tabRefreshCounts = {};
  int _lastTabIndex = 0;
  bool _isHeaderExpanded = false; // Collapsed by default to save screen space

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
          onDataChanged: _loadSite,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteAdditionalExpenses,
        title: 'Additional',
        icon: Icons.receipt_long_outlined,
        builder: (refreshCount) => SiteAdditionalExpenseTab(
          key: ValueKey('additional_$refreshCount'),
          siteId: widget.siteId,
          onDataChanged: _loadSite,
        ),
      ),
      _SiteTabDefinition(
        key: AppModules.siteBudget,
        title: 'VAT Details',
        icon: Icons.receipt_long_rounded,
        builder: (refreshCount) => SiteBudgetTab(
          key: ValueKey('vat_details_$refreshCount'),
          siteId: widget.siteId,
          siteName: widget.initialSite?.name,
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
      final results = await Future.wait([
        _supabase.from('site_summary').select('received_amount, cash_expenses').eq('site_id', widget.siteId),
        _supabase.from('labour_costs').select('amount').eq('site_id', widget.siteId),
        _supabase.from('material_costs').select('invoice_amount, vat_amount').eq('site_id', widget.siteId),
        _supabase.from('subcontractors').select('invoice_amount, vat_amount').eq('site_id', widget.siteId),
        _supabase.from('additional_expenses').select('amount').eq('site_id', widget.siteId),
      ]);

      double receivedSum = 0.0;
      double summarySpent = 0.0;
      for (var s in (results[0] as List)) {
        receivedSum += _toDouble(s['received_amount']);
        summarySpent += _toDouble(s['cash_expenses']);
      }

      double labourSpent = 0.0;
      for (var l in (results[1] as List)) {
        labourSpent += _toDouble(l['amount']);
      }

      double materialSpent = 0.0;
      for (var m in (results[2] as List)) {
        materialSpent += _toDouble(m['invoice_amount']) + _toDouble(m['vat_amount']);
      }

      double subcontractorSpent = 0.0;
      for (var sc in (results[3] as List)) {
        subcontractorSpent += _toDouble(sc['invoice_amount']) + _toDouble(sc['vat_amount']);
      }

      double additionalSpent = 0.0;
      for (var a in (results[4] as List)) {
        additionalSpent += _toDouble(a['amount']);
      }

      final totalSpent = summarySpent + labourSpent + materialSpent + subcontractorSpent + additionalSpent;

      return Site(
        id: baseSite.id,
        name: baseSite.name,
        code: baseSite.code,
        clientName: baseSite.clientName,
        location: baseSite.location,
        startDate: baseSite.startDate,
        status: baseSite.status,
        assignedBudget: baseSite.assignedBudget,
        spent: totalSpent,
        receivedSummary: receivedSum > 0 ? receivedSum : baseSite.receivedSummary,
        summarySpent: summarySpent,
        labourSpent: labourSpent,
        materialSpent: materialSpent,
        subcontractorSpent: subcontractorSpent,
        additionalSpent: additionalSpent,
        createdAt: baseSite.createdAt,
        updatedAt: baseSite.updatedAt,
      );
    } catch (_) {
      return baseSite;
    }
  }

  void _showSpendBreakdownDialog(BuildContext context, Site site) {
    final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
    final items = [
      {'title': 'Summary (Expenses)', 'amount': site.summarySpent, 'icon': Icons.table_chart_outlined, 'color': const Color(0xFF0B5ED7)},
      {'title': 'Labour Costs', 'amount': site.labourSpent, 'icon': Icons.engineering_outlined, 'color': const Color(0xFFD97706)},
      {'title': 'Material Costs', 'amount': site.materialSpent, 'icon': Icons.inventory_outlined, 'color': const Color(0xFF10B981)},
      {'title': 'Sub-Contractors', 'amount': site.subcontractorSpent, 'icon': Icons.handshake_outlined, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Additional Expenses', 'amount': site.additionalSpent, 'icon': Icons.receipt_long_outlined, 'color': const Color(0xFFEC4899)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Spend Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      currencyFormat.format(site.spent),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Combined expenditure from all 5 site modules:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(item['icon'] as IconData, size: 16, color: item['color'] as Color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0A2540)),
                            ),
                          ),
                          Text(
                            currencyFormat.format(item['amount'] as double),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                          ),
                        ],
                      ),
                    ),
                  )),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Aggregated Spend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2540))),
                  Text(
                    currencyFormat.format(site.spent),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B5ED7)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
              // Top Site Header Banner (Compact & Collapsible)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: _isHeaderExpanded ? 12 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2540),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Strip (Always visible, tap to toggle expand/collapse)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
                        child: Row(
                          children: [
                            if (site?.code != null && site!.code!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  site.code!,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                site?.name ?? 'Loading Site...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isLiveActive ? const Color(0xFFE6F4EA) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isLiveActive ? const Color(0xFF00C853) : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    (site?.status ?? 'Active').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isLiveActive ? const Color(0xFF137333) : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canEditSite) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                            const SizedBox(width: 2),
                            // Chevron Button to expand or collapse
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isHeaderExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Collapsible Content (Hidden by default, drops down on arrow click)
                      if (_isHeaderExpanded) ...[
                        const SizedBox(height: 10),
                        // Lead / Client & Location Row
                        if (site != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor: Colors.blue[100],
                                  child: Text(
                                    site.clientName != null && site.clientName!.isNotEmpty ? site.clientName![0].toUpperCase() : 'S',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Client: ${site.clientName ?? 'N/A'}  |  Location: ${site.location ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Financial Metric Bar
                        if (canViewFinancials) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Assigned Budget', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormat.format(site?.assignedBudget ?? 0),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: site == null ? null : () => _showSpendBreakdownDialog(context, site),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text('Total Spend', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                                          SizedBox(width: 3),
                                          Icon(Icons.info_outline, size: 10, color: Colors.white60),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currencyFormat.format(site?.spent ?? 0),
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Remaining Balance', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormat.format((site?.assignedBudget ?? 0) - (site?.spent ?? 0)),
                                    style: TextStyle(
                                      color: ((site?.assignedBudget ?? 0) - (site?.spent ?? 0)) < 0 ? Colors.redAccent : Colors.greenAccent,
                                      fontSize: 14,
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
                              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 13),
                              const SizedBox(width: 6),
                              Text(
                                'Started: ${site?.startDate != null ? dateFormat.format(site!.startDate!) : 'N/A'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Role Restricted View',
                                  style: TextStyle(color: Colors.white70, fontSize: 10.5),
                                ),
                              ),
                            ],
                          ),
                        ],
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
