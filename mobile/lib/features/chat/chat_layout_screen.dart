import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import 'models/conversation.dart';
import 'widgets/conversation_list_item.dart';
import 'chat_detail_view.dart';
import 'chat_detail_screen.dart';

class ChatLayoutScreen extends StatefulWidget {
  const ChatLayoutScreen({super.key});

  @override
  State<ChatLayoutScreen> createState() => _ChatLayoutScreenState();
}

class _ChatLayoutScreenState extends State<ChatLayoutScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Conversation>> _conversationsFuture;
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Groups', 'Sites'
  String _searchQuery = '';
  Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _loadConversations() {
    setState(() {
      _conversationsFuture = _fetchConversations();
    });
  }

  Future<List<Conversation>> _fetchConversations() async {
    final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;

    final employeesData = await _apiService.getEmployees();
    final sitesData = await _apiService.getSites();

    final List<Conversation> list = [];

    // Map Employees
    for (final emp in employeesData) {
      final email = emp['email']?.toString();
      if (email == currentUserEmail) continue; // Skip logged in user

      final id = emp['id']?.toString() ?? '';
      final name = emp['name']?.toString() ?? 'Employee';
      final role = emp['role']?.toString() ?? 'Staff';

      list.add(Conversation(
        id: id,
        title: name,
        subtitle: role,
        type: ConversationType.personal,
        isOnline: true,
      ));
    }

    // Map Sites
    for (final site in sitesData) {
      list.add(Conversation(
        id: site.id,
        title: site.name,
        subtitle: 'Site Group Chat',
        type: ConversationType.siteGroup,
        isOnline: true,
      ));
    }

    return list;
  }

  List<Conversation> _filterConversations(List<Conversation> all) {
    return all.where((c) {
      // Search filter
      if (_searchQuery.isNotEmpty && !c.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }

      // Filter chips
      if (_selectedFilter == 'Unread') return c.unreadCount > 0;
      if (_selectedFilter == 'Groups') return c.type != ConversationType.personal;
      if (_selectedFilter == 'Sites') return c.type == ConversationType.siteGroup;

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          // Desktop / Tablet Split View Layout
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 360,
                  child: _buildSidebar(isWide: true),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: _selectedConversation != null
                      ? ChatDetailView(
                          key: ValueKey(_selectedConversation!.id),
                          title: _selectedConversation!.title,
                          entityId: _selectedConversation!.id,
                          isGroupChat: _selectedConversation!.type != ConversationType.personal,
                        )
                      : Container(
                          color: const Color(0xFFF0F2F5),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_outlined,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'AL NADHEERA CONSTRUCTION CHAT',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Select an employee or site chat to start messaging',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Single View
          return Scaffold(
            appBar: AppBar(
              title: const Text('AL NADHEERA CHAT'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadConversations,
                ),
              ],
            ),
            body: _buildSidebar(isWide: false),
          );
        }
      },
    );
  }

  Widget _buildSidebar({required bool isWide}) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Sidebar Header
        if (isWide)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Icon(Icons.business_center_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AL NADHEERA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadConversations,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: ['All', 'Unread', 'Groups', 'Sites'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 1),

        // Conversations List
        Expanded(
          child: FutureBuilder<List<Conversation>>(
            future: _conversationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error loading chats: ${snapshot.error}'));
              }

              final allConversations = snapshot.data ?? [];
              final filtered = _filterConversations(allConversations);

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No conversations found', style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final conv = filtered[index];
                  final isSelected = _selectedConversation?.id == conv.id;

                  return ConversationListItem(
                    conversation: conv,
                    isSelected: isWide && isSelected,
                    onTap: () {
                      if (isWide) {
                        setState(() {
                          _selectedConversation = conv;
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              title: conv.title,
                              entityId: conv.id,
                              isGroupChat: conv.type != ConversationType.personal,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
