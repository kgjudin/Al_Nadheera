import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'note_details_screen.dart';
import '../../core/utils/file_helper.dart';

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
  bool _isUploading = false;
  String _uploadStatus = '';

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

  Future<void> _pickAndUploadDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'doc', 'docx', 'txt'],
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Preparing ${result.files.length} document(s)...';
      });

      int count = 0;
      Map<String, dynamic>? lastCreatedNote;

      for (final file in result.files) {
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && !kIsWeb && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null) continue;

        setState(() {
          _uploadStatus = 'Uploading ${file.name}...';
        });

        // 1. Create a note container for this document
        final newNote = await _supabase
            .from('personal_notes')
            .insert({
              'folder_id': widget.folderId,
              'title': file.name,
              'content': 'Attached file: ${file.name}',
            })
            .select()
            .single();

        lastCreatedNote = newNote;
        final noteId = newNote['id']?.toString();
        if (noteId == null) continue;

        // 2. Upload file to personal-data bucket
        final safeName = FileHelper.sanitizeFileName(file.name);
        final filePath = 'notes/$noteId/${const Uuid().v4()}_$safeName';

        await _supabase.storage.from('personal-data').uploadBinary(
              filePath,
              fileBytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: true,
                contentType: FileHelper.getMimeType(file.name),
              ),
            );

        final fileUrl = _supabase.storage.from('personal-data').getPublicUrl(filePath);

        // 3. Associate with note
        await _supabase.from('personal_note_images').insert({
          'note_id': noteId,
          'image_url': fileUrl,
        });

        count++;
      }

      _loadNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Document added successfully!'
                  : '$count documents added successfully!',
            ),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
          ),
        );

        if (count == 1 && lastCreatedNote != null) {
          _navigateToNote(note: lastCreatedNote);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note / Document'),
        content: Text('Are you sure you want to delete "${note['title'] ?? 'this item'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final noteId = note['id'];
      if (noteId == null) return;

      // Delete child attachments from DB
      await _supabase.from('personal_note_images').delete().eq('note_id', noteId);

      // Delete note
      await _supabase.from('personal_notes').delete().eq('id', noteId);

      _loadNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add to Folder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFF0F766E)),
                ),
                title: const Text('Upload PDF / Excel / Document'),
                subtitle: const Text('Add PDF, Excel (.xlsx, .xls), CSV, or Word files'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadDocument();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.note_alt_outlined, color: Colors.blue),
                ),
                title: const Text('Create Text Note'),
                subtitle: const Text('Write a new note or memo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToNote();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteLeading(Map<String, dynamic> note) {
    final title = (note['title'] ?? '').toString();
    final type = FileHelper.getFileType(title);

    Color color;
    IconData icon;

    switch (type) {
      case AppFileType.pdf:
        color = const Color(0xFFDC2626);
        icon = Icons.picture_as_pdf_rounded;
        break;
      case AppFileType.excel:
        color = const Color(0xFF16A34A);
        icon = Icons.table_chart_rounded;
        break;
      case AppFileType.doc:
        color = const Color(0xFF2563EB);
        icon = Icons.description_rounded;
        break;
      default:
        color = const Color(0xFF0F766E);
        icon = Icons.note_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload PDF / Excel',
            onPressed: _isUploading ? null : _pickAndUploadDocument,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'New Note',
            onPressed: () => _navigateToNote(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading document...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No documents or notes in this folder',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _navigateToNote(),
                                icon: const Icon(Icons.note_add_outlined, size: 18),
                                label: const Text('Create Note'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F766E),
                                  side: const BorderSide(color: Color(0xFF0F766E)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _pickAndUploadDocument,
                                icon: const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
                                label: const Text('Upload PDF/Excel', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final title = note['title'] ?? 'Untitled';
                    final content = (note['content'] ?? '').toString();
                    final type = FileHelper.getFileType(title);
                    final isDoc = type != AppFileType.image && type != AppFileType.other;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: () => _navigateToNote(note: note),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              _buildNoteLeading(note),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      content.isNotEmpty ? content : 'No additional text',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isDoc) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          type == AppFileType.pdf
                                              ? 'PDF Document'
                                              : (type == AppFileType.excel ? 'Excel Spreadsheet' : 'Document'),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
                                onSelected: (val) {
                                  if (val == 'open') {
                                    _navigateToNote(note: note);
                                  } else if (val == 'delete') {
                                    _deleteNote(note);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Row(
                                      children: [
                                        Icon(Icons.open_in_new, size: 18),
                                        SizedBox(width: 8),
                                        Text('Open'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: const Color(0xFF0F766E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
