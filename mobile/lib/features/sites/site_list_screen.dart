import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/site_model.dart';
import 'add_edit_site_screen.dart';
import 'site_details_screen.dart';
import '../../core/widgets/profile_avatar_button.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Site>> _sitesFuture;
  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  void _loadSites() {
    setState(() {
      _sitesFuture = _apiService.getSites();
    });
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddSite(),
        child: const Icon(Icons.add),
      ),
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
                      Text(site.receivedSummary > 0 ? 'Given' : 'Budget', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(currencyFormat.format(site.effectiveGiven), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Spent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(currencyFormat.format(site.spent), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
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
