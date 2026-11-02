import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../services/camera/app_camera_service.dart';
import '../../core/utils/file_helper.dart';

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
      debugPrint('Error loading note attachments: $e');
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
      final mimeType = FileHelper.getMimeType(pickedFile.name);
      final safeName = FileHelper.sanitizeFileName(pickedFile.name);
      final fileName = '${const Uuid().v4()}_$safeName';
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

  Future<void> _pickAndUploadDocument() async {
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

      int uploadedCount = 0;
      for (final file in result.files) {
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && !kIsWeb && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null) continue;

        setState(() {
          _uploadStatus = 'Uploading ${file.name}...';
        });

        final safeName = FileHelper.sanitizeFileName(file.name);
        final filePath = 'notes/$_noteId/${const Uuid().v4()}_$safeName';

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

        await _supabase.from('personal_note_images').insert({
          'note_id': _noteId,
          'image_url': fileUrl,
        });

        // If title is Untitled Note, set it to the first file's name
        if (_titleCtrl.text.trim().isEmpty || _titleCtrl.text.trim() == 'Untitled Note') {
          final cleanTitle = file.name.contains('.')
              ? file.name.substring(0, file.name.lastIndexOf('.'))
              : file.name;
          _titleCtrl.text = cleanTitle;
          await _supabase.from('personal_notes').update({
            'title': cleanTitle,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', _noteId as Object);
        }

        uploadedCount++;
      }

      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadedCount == 1
                  ? 'Document attached successfully!'
                  : '$uploadedCount documents attached successfully!',
            ),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
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

  Future<void> _openFileUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file in external application')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<void> _deleteAttachment(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attachment'),
        content: const Text('Are you sure you want to remove this attachment?'),
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
      final itemId = item['id'];
      final itemUrl = item['image_url'] as String? ?? '';

      // Delete from DB
      await _supabase.from('personal_note_images').delete().eq('id', itemId as Object);

      // Best effort delete from storage
      try {
        final uri = Uri.parse(itemUrl);
        final pathSegments = uri.pathSegments;
        final personalDataIndex = pathSegments.indexOf('personal-data');
        if (personalDataIndex != -1 && personalDataIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(personalDataIndex + 1).join('/');
          await _supabase.storage.from('personal-data').remove([Uri.decodeComponent(storagePath)]);
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
          SnackBar(content: Text('Error deleting attachment: $e')),
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

  void _showAttachmentSheet() {
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
                'Add Attachment',
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
                title: const Text('PDF, Excel or Document'),
                subtitle: const Text('Attach PDF, XLSX, XLS, CSV, DOCX files'),
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
                  child: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                ),
                title: const Text('Photo Gallery'),
                subtitle: const Text('Select photos from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.teal),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture using device camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final url = doc['image_url'] as String? ?? '';
    final fileName = FileHelper.getDisplayName(url);
    final type = FileHelper.getFileType(fileName.isNotEmpty ? fileName : url);

    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (type) {
      case AppFileType.pdf:
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.picture_as_pdf_rounded;
        typeLabel = 'PDF';
        break;
      case AppFileType.excel:
        typeColor = const Color(0xFF16A34A);
        typeIcon = Icons.table_chart_rounded;
        typeLabel = 'EXCEL';
        break;
      case AppFileType.doc:
        typeColor = const Color(0xFF2563EB);
        typeIcon = Icons.description_rounded;
        typeLabel = 'DOC';
        break;
      default:
        typeColor = const Color(0xFF0F766E);
        typeIcon = Icons.insert_drive_file_rounded;
        typeLabel = 'FILE';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.grey.shade50,
      child: InkWell(
        onTap: () => _openFileUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to open & view',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF0F766E), size: 20),
                tooltip: 'Open',
                onPressed: () => _openFileUrl(url),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                tooltip: 'Delete',
                onPressed: () => _deleteAttachment(doc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Separate attachments into documents and photos
    final documents = <Map<String, dynamic>>[];
    final photos = <Map<String, dynamic>>[];

    for (final item in _images) {
      final url = item['image_url'] as String? ?? '';
      final fileName = FileHelper.getDisplayName(url);
      final type = FileHelper.getFileType(fileName.isNotEmpty ? fileName : url);
      if (type == AppFileType.image) {
        photos.add(item);
      } else {
        documents.add(item);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'Add Attachment',
            onPressed: _showAttachmentSheet,
          ),
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

            // Documents Section
            if (documents.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text(
                    'Documents (${documents.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...documents.map((doc) => _buildDocumentCard(doc)),
              const SizedBox(height: 16),
            ],

            // Photos Section
            if (photos.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text(
                    'Photos (${photos.length})',
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
                children: photos.map((img) {
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
                          onTap: () => _deleteAttachment(img),
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
                    Expanded(
                      child: Text(
                        _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading file...',
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
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Photos', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickAndUploadDocument,
                      icon: const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
                      label: const Text('PDF / Excel', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
