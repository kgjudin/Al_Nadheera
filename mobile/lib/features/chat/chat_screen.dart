import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../models/site_model.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  late Future<List<dynamic>> _employeesFuture;
  late Future<List<Site>> _sitesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _employeesFuture = _apiService.getEmployees();
    _sitesFuture = _apiService.getSites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Employees'),
            Tab(text: 'Sites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Employees Tab
          FutureBuilder<List<dynamic>>(
            future: _employeesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading employees: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No employees found.'));
              }

              // Get current user ID to filter them out of the list
              final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
              
              final employees = snapshot.data!.where((e) {
                // Assuming the employee record has an email or user_id field that matches Auth
                final email = e['email']?.toString();
                return email != currentUserEmail;
              }).toList();

              if (employees.isEmpty) {
                return const Center(child: Text('No other employees to chat with.'));
              }

              return ListView.builder(
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  final id = employee['id']?.toString() ?? '';
                  final name = employee['name'] ?? 'Unknown';
                  final role = employee['role'] ?? 'Employee';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            title: name,
                            entityId: id,
                            isGroupChat: false,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          // Sites Tab
          FutureBuilder<List<Site>>(
            future: _sitesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading sites: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No sites found.'));
              }

              final sites = snapshot.data!;
              return ListView.builder(
                itemCount: sites.length,
                itemBuilder: (context, index) {
                  final site = sites[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      child: Icon(Icons.business_rounded, color: Theme.of(context).colorScheme.secondary),
                    ),
                    title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Group Chat for ${site.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Site Group',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            title: site.name,
                            entityId: site.id,
                            isGroupChat: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
