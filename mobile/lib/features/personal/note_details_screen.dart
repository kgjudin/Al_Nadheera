import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class NoteDetailsScreen extends StatefulWidget {
  final String folderId;
  final Map<String, dynamic>? note;

  const NoteDetailsScreen({super.key, required this.folderId, this.note});

  @override
  State<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends State<NoteDetailsScreen> {
  final _supabase = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  
  String? _noteId;
  List<Map<String, dynamic>> _images = [];
  bool _isSaving = false;
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _noteId = widget.note!['id'];
      _titleCtrl.text = widget.note!['title'] ?? '';
      _contentCtrl.text = widget.note!['content'] ?? '';
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    if (_noteId == null) return;
    try {
      final images = await _supabase
          .from('personal_note_images')
          .select()
          .eq('note_id', _noteId as Object)
          .order('created_at', ascending: true);
      if (mounted) setState(() => _images = images);
    } catch (e) {
      // Handle
    }
  }

  Future<void> _saveNote() async {
    setState(() => _isSaving = true);
    try {
      if (_noteId == null) {
        final res = await _supabase.from('personal_notes').insert({
          'folder_id': widget.folderId,
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
        }).select().single();
        _noteId = res['id'];
      } else {
        await _supabase.from('personal_notes').update({
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
        }).eq('id', _noteId as Object);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note Saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadImage(ImageSource source) async {
    if (_noteId == null) {
      // Must save note first to attach images
      await _saveNote();
      if (_noteId == null) return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final fileExt = image.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'notes/$_noteId/$fileName';

      await _supabase.storage.from('personal-data').upload(
            filePath,
            File(image.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage.from('personal-data').getPublicUrl(filePath);

      await _supabase.from('personal_note_images').insert({
        'note_id': _noteId,
        'image_url': imageUrl,
      });

      _loadImages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                hintText: 'Type your note here...',
                border: InputBorder.none,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            if (_images.isNotEmpty) ...[
              const Text('Attachments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images.map((img) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img['image_url'],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _uploadImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _uploadImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
