import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'note_details_screen.dart';

class NotesScreen extends StatefulWidget {
  final String folderId;
  final String folderName;

  const NotesScreen({super.key, required this.folderId, required this.folderName});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    setState(() {
      _notesFuture = _supabase
          .from('personal_notes')
          .select()
          .eq('folder_id', widget.folderId)
          .order('created_at', ascending: false);
    });
  }

  void _navigateToNote({Map<String, dynamic>? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailsScreen(
          folderId: widget.folderId,
          note: note,
        ),
      ),
    ).then((_) => _loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No notes in this folder.', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _navigateToNote, child: const Text('Create Note')),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(note['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    note['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _navigateToNote(note: note),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
