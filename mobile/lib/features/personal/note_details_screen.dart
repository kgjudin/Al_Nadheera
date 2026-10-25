import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../services/camera/app_camera_service.dart';

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
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _noteId = widget.note!['id']?.toString();
      _titleCtrl.text = widget.note!['title']?.toString() ?? '';
      _contentCtrl.text = widget.note!['content']?.toString() ?? '';
      _loadImages();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    if (_noteId == null) return;
    try {
      final images = await _supabase
          .from('personal_note_images')
          .select()
          .eq('note_id', _noteId as Object)
          .order('created_at', ascending: true);
      if (mounted) setState(() => _images = List<Map<String, dynamic>>.from(images));
    } catch (e) {
      debugPrint('Error loading note images: $e');
    }
  }

  Future<bool> _saveNote({bool silent = false}) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);

    try {
      final title = _titleCtrl.text.trim().isEmpty ? 'Untitled Note' : _titleCtrl.text.trim();
      final content = _contentCtrl.text.trim();

      if (_noteId == null) {
        final res = await _supabase.from('personal_notes').insert({
          'folder_id': widget.folderId,
          'title': title,
          'content': content,
        }).select().single();
        _noteId = res['id']?.toString();
      } else {
        await _supabase.from('personal_notes').update({
          'title': title,
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _noteId as Object);
      }

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note Saved'),
            backgroundColor: Color(0xFF0F766E),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadImage(ImageSource source) async {
    // Save note first so we have an ID for storage path and association
    if (_noteId == null) {
      final saved = await _saveNote(silent: true);
      if (!saved || _noteId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not initialize note. Please save first.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    try {
      XFile? pickedFile;
      if (source == ImageSource.camera) {
        final photo = await AppCameraService.capturePhoto(context);
        pickedFile = photo?.toXFile();
      } else {
        final picker = ImagePicker();
        pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
      }
      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Reading image...';
      });

      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.name.split('.').last.toLowerCase();
      final mimeType = fileExt == 'png'
          ? 'image/png'
          : (fileExt == 'webp' ? 'image/webp' : 'image/jpeg');
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'notes/$_noteId/$fileName';

      setState(() => _uploadStatus = 'Uploading to cloud...');

      await _supabase.storage.from('personal-data').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: mimeType,
            ),
          );

      final imageUrl = _supabase.storage.from('personal-data').getPublicUrl(filePath);

      setState(() => _uploadStatus = 'Attaching image...');

      await _supabase.from('personal_note_images').insert({
        'note_id': _noteId,
        'image_url': imageUrl,
      });

      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image attached successfully!'),
            backgroundColor: Color(0xFF0F766E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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

  Future<void> _deleteImage(Map<String, dynamic> img) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attachment'),
        content: const Text('Are you sure you want to remove this photo?'),
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
      final imgId = img['id'];
      final imgUrl = img['image_url'] as String? ?? '';

      // Delete from DB
      await _supabase.from('personal_note_images').delete().eq('id', imgId as Object);

      // Best effort delete from storage
      try {
        final uri = Uri.parse(imgUrl);
        final pathSegments = uri.pathSegments;
        final personalDataIndex = pathSegments.indexOf('personal-data');
        if (personalDataIndex != -1 && personalDataIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(personalDataIndex + 1).join('/');
          await _supabase.storage.from('personal-data').remove([storagePath]);
        }
      } catch (_) {}

      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
      }
    }
  }

  void _showFullscreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.8),
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Image Preview', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                cacheWidth: 1200,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save Note',
              onPressed: () => _saveNote(),
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
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                hintText: 'Type your note here...',
                border: InputBorder.none,
              ),
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 20),
            if (_images.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attachments (${_images.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _images.map((img) {
                  final url = img['image_url'] as String? ?? '';
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showFullscreenImage(url),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade100,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            url,
                            cacheWidth: 400,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deleteImage(img),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (_isUploading)
              Container(
                padding: const EdgeInsets.all(16),
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
                    Text(
                      _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading image...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0F766E)),
                      label: const Text('Camera', style: TextStyle(color: Color(0xFF0F766E))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                      label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
