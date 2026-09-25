import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_screen.dart';
import '../../core/widgets/profile_avatar_button.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
    setState(() {
      _foldersFuture = _supabase
          .from('personal_folders')
          .select()
          .order('created_at', ascending: false);
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Folder Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    await _supabase.from('personal_folders').insert({
                      'name': name,
                      'user_id': _supabase.auth.currentUser!.id,
                    });
                    _loadFolders();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _showAddDialog,
            tooltip: 'New Folder',
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _foldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final folders = snapshot.data ?? [];
          if (folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_shared, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No folders yet.', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _showAddDialog, child: const Text('Create Folder')),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotesScreen(
                        folderId: folder['id'],
                        folderName: folder['name'],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder, size: 48, color: Colors.blue[300]),
                      const SizedBox(height: 8),
                      Text(
                        folder['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
