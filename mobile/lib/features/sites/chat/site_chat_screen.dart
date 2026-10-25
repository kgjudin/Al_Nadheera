import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/camera/app_camera_service.dart';

class SiteChatScreen extends StatefulWidget {
  final String siteId;
  final String siteName;

  const SiteChatScreen({super.key, required this.siteId, required this.siteName});

  @override
  State<SiteChatScreen> createState() => _SiteChatScreenState();
}

class _SiteChatScreenState extends State<SiteChatScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  String? _myUserId;
  bool _isUploading = false;
  String _uploadStatus = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser?.id;
    _markSiteAsRead();
    
    // Listen to real-time changes with deduplication
    _messagesStream = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('site_id', widget.siteId)
        .order('created_at', ascending: true)
        .map((messages) {
          final seenIds = <String>{};
          final unique = <Map<String, dynamic>>[];
          for (final msg in messages) {
            final id = msg['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (!seenIds.add(id)) {
                continue; // Skip duplicate
              }
            }
            unique.add(msg);
          }
          return unique;
        });
  }

  Future<void> _markSiteAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_last_read_${widget.siteId}', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _sendMessage({
    String? mediaUrl,
    String? messageType,
    String? fileName,
    int? fileSize,
  }) async {
    if (_isSending) return;
    final text = _msgController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;
    
    _isSending = true;
    _msgController.clear();
    
    try {
      final type = messageType ?? (mediaUrl != null ? 'image' : 'text');
      final clientMsgId = const Uuid().v4();
      await _supabase.from('chat_messages').insert({
        'id': clientMsgId,
        'site_id': widget.siteId,
        'sender_id': _myUserId,
        'message': text.isNotEmpty ? text : (type == 'image' ? 'Photo' : (fileName ?? 'Attachment')),
        'message_type': type,
        'media_url': mediaUrl,
        if (fileName != null) 'file_name': fileName,
        if (fileSize != null) 'file_size': fileSize,
      });
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _isSending = false;
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      XFile? image;
      if (source == ImageSource.camera) {
        final photo = await AppCameraService.capturePhoto(context);
        image = photo?.toXFile();
      } else {
        image = await _picker.pickImage(source: source, imageQuality: 80);
      }
      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Uploading photo...';
      });

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'chat/${widget.siteId}/$fileName';

      await _supabase.storage.from('chat-media').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(image.name),
              upsert: true,
            ),
          );

      final imageUrl = _supabase.storage.from('chat-media').getPublicUrl(filePath);

      await _sendMessage(mediaUrl: imageUrl, messageType: 'image');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
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
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null && !kIsWeb && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Uploading ${file.name}...';
      });

      final fileExt = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'bin';
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'chat/${widget.siteId}/$fileName';

      await _supabase.storage.from('chat-media').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(file.name),
              upsert: true,
            ),
          );

      final fileUrl = _supabase.storage.from('chat-media').getPublicUrl(filePath);

      await _sendMessage(
        mediaUrl: fileUrl,
        messageType: 'document',
        fileName: file.name,
        fileSize: fileBytes.length,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _openFullScreenImage(String imageUrl, String? caption) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(caption ?? 'Photo', style: const TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFileUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.siteName} Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final rawMessages = snapshot.data ?? [];
                if (rawMessages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markSiteAsRead();
                  });
                }
                final seenIds = <String>{};
                final messages = <Map<String, dynamic>>[];
                for (final m in rawMessages) {
                  final id = m['id']?.toString() ?? '';
                  if (id.isNotEmpty && !seenIds.add(id)) {
                    continue;
                  }
                  messages.add(m);
                }

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Start the conversation!'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myUserId;
                    final mType = msg['message_type'];
                    final mediaUrl = msg['media_url']?.toString();
                    final date = msg['created_at'] != null ? DateTime.parse(msg['created_at']) : DateTime.now();

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
                            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mType == 'image' && mediaUrl != null) ...[
                              GestureDetector(
                                onTap: () => _openFullScreenImage(mediaUrl, msg['message']),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    mediaUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    cacheWidth: 800,
                                    loadingBuilder: (ctx, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 160,
                                        color: const Color(0xFFF0F2F5),
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, error, stackTrace) => Container(
                                      height: 120,
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (msg['message'] != null && msg['message'].toString().isNotEmpty && msg['message'].toString() != 'Photo')
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    msg['message'],
                                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                                  ),
                                ),
                            ] else if ((mType == 'document' || mType == 'file') && mediaUrl != null) ...[
                              InkWell(
                                onTap: () => _openFileUrl(mediaUrl),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_drive_file_rounded, color: Colors.indigo, size: 30),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          msg['file_name'] ?? msg['message'] ?? 'Document',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      const Icon(Icons.download_rounded, color: Colors.grey, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (msg['message'] != null && msg['message'].toString().isNotEmpty) ...[
                              Text(
                                msg['message'],
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                timeago.format(date),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    color: Colors.blue,
                    onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.camera),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo),
                    color: Colors.blue,
                    onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.blue,
                    onPressed: _isUploading ? null : _pickAndUploadDocument,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      enabled: !_isUploading,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isUploading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
