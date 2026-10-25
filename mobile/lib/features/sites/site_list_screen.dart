import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../models/site_model.dart';
import 'add_edit_site_screen.dart';
import 'site_details_screen.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../services/permission_service.dart';
import '../../core/constants/app_modules.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Site>> _sitesFuture;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  void _loadSites() {
    setState(() {
      _sitesFuture = _fetchLiveSites();
    });
  }

  Future<List<Site>> _fetchLiveSites() async {
    List<Site> baseSites = [];
    try {
      baseSites = await _apiService.getSites();
    } catch (_) {
      try {
        final supabase = Supabase.instance.client;
        final data = await supabase.from('sites').select('*').order('created_at', ascending: false);
        baseSites = (data as List).map((json) => Site.fromJson(json)).toList();
      } catch (_) {
        baseSites = [];
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final results = await Future.wait([
        supabase.from('site_summary').select('site_id, received_amount, cash_expenses'),
        supabase.from('labour_costs').select('site_id, amount'),
        supabase.from('material_costs').select('site_id, invoice_amount, vat_amount'),
        supabase.from('subcontractors').select('site_id, invoice_amount, vat_amount'),
        supabase.from('additional_expenses').select('site_id, amount'),
      ]);

      final summaries = results[0] as List;
      final labours = results[1] as List;
      final materials = results[2] as List;
      final subcontracts = results[3] as List;
      final additionals = results[4] as List;

      final Map<String, double> siteReceived = {};
      final Map<String, double> siteSummarySpent = {};
      final Map<String, double> siteLabourSpent = {};
      final Map<String, double> siteMaterialSpent = {};
      final Map<String, double> siteSubcontractorSpent = {};
      final Map<String, double> siteAdditionalSpent = {};

      for (var s in summaries) {
        final sid = s['site_id']?.toString() ?? '';
        siteReceived[sid] = (siteReceived[sid] ?? 0) + _toDouble(s['received_amount']);
        siteSummarySpent[sid] = (siteSummarySpent[sid] ?? 0) + _toDouble(s['cash_expenses']);
      }
      for (var l in labours) {
        final sid = l['site_id']?.toString() ?? '';
        siteLabourSpent[sid] = (siteLabourSpent[sid] ?? 0) + _toDouble(l['amount']);
      }
      for (var m in materials) {
        final sid = m['site_id']?.toString() ?? '';
        siteMaterialSpent[sid] = (siteMaterialSpent[sid] ?? 0) + _toDouble(m['invoice_amount']) + _toDouble(m['vat_amount']);
      }
      for (var sc in subcontracts) {
        final sid = sc['site_id']?.toString() ?? '';
        siteSubcontractorSpent[sid] = (siteSubcontractorSpent[sid] ?? 0) + _toDouble(sc['invoice_amount']) + _toDouble(sc['vat_amount']);
      }
      for (var a in additionals) {
        final sid = a['site_id']?.toString() ?? '';
        siteAdditionalSpent[sid] = (siteAdditionalSpent[sid] ?? 0) + _toDouble(a['amount']);
      }

      return baseSites.map((s) {
        final rec = siteReceived.containsKey(s.id) ? siteReceived[s.id]! : s.receivedSummary;
        final sumSpent = siteSummarySpent[s.id] ?? s.summarySpent;
        final labSpent = siteLabourSpent[s.id] ?? s.labourSpent;
        final matSpent = siteMaterialSpent[s.id] ?? s.materialSpent;
        final subSpent = siteSubcontractorSpent[s.id] ?? s.subcontractorSpent;
        final addSpent = siteAdditionalSpent[s.id] ?? s.additionalSpent;
        final totSpent = sumSpent + labSpent + matSpent + subSpent + addSpent;

        return Site(
          id: s.id,
          name: s.name,
          code: s.code,
          clientName: s.clientName,
          location: s.location,
          startDate: s.startDate,
          status: s.status,
          assignedBudget: s.assignedBudget,
          spent: totSpent > 0 ? totSpent : s.spent,
          receivedSummary: rec > 0 ? rec : s.receivedSummary,
          summarySpent: sumSpent,
          labourSpent: labSpent,
          materialSpent: matSpent,
          subcontractorSpent: subSpent,
          additionalSpent: addSpent,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
        );
      }).toList();
    } catch (_) {
      return baseSites;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Sites', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSites,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadSites();
          await _sitesFuture;
        },
        child: FutureBuilder<List<Site>>(
          future: _sitesFuture,
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
                    const Icon(Icons.business, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No sites found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToAddSite(),
                      child: const Text('Add New Site'),
                    ),
                  ],
                ),
              );
            }

            final sites = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                return _buildSiteCard(site);
              },
            );
          },
        ),
      ),
      floatingActionButton: PermissionService.instance.canCreate(AppModules.sites)
          ? FloatingActionButton(
              onPressed: () => _navigateToAddSite(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSiteCard(Site site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SiteDetailsScreen(siteId: site.id),
            ),
          ).then((_) => _loadSites());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      site.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: site.status == 'Active' ? Colors.green[50] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      site.status,
                      style: TextStyle(
                        color: site.status == 'Active' ? Colors.green[800] : Colors.grey[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (site.code != null && site.code!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Code: ${site.code}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Budget', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(site.assignedBudget),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Spent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(site.spent),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Balance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(site.remainingBalance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: site.remainingBalance < 0 ? Colors.red : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddSite() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditSiteScreen()),
    ).then((_) => _loadSites());
  }
}
