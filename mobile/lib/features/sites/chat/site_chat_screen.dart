import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

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

  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser?.id;
    _markSiteAsRead();
    
    // Listen to real-time changes
    _messagesStream = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('site_id', widget.siteId)
        .order('created_at', ascending: true);
  }

  Future<void> _markSiteAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_last_read_${widget.siteId}', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _msgController.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    
    _msgController.clear();
    
    try {
      await _supabase.from('chat_messages').insert({
        'site_id': widget.siteId,
        'sender_id': _myUserId,
        'message': text.isNotEmpty ? text : null,
        'message_type': imageUrl != null ? 'image' : 'text',
        'media_url': imageUrl,
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
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);

      final fileExt = image.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'chat/${widget.siteId}/$fileName';

      // Upload to Supabase Storage
      // If we're on web, image.path might not work directly with File, so we use readAsBytes for web compatibility
      // But assuming mobile (Android/iOS/Windows Desktop) for this context, File(image.path) works.
      await _supabase.storage.from('chat-media').upload(
            filePath,
            File(image.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage.from('chat-media').getPublicUrl(filePath);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
    } finally {
      setState(() => _isUploading = false);
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
                
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markSiteAsRead();
                  });
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
                    final isImage = msg['message_type'] == 'image';
                    final date = DateTime.parse(msg['created_at']);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[600] : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isImage && msg['media_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  msg['media_url'],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  },
                                ),
                              ),
                            if (isImage && msg['message'] != null && msg['message'].toString().isNotEmpty)
                              const SizedBox(height: 8),
                            if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                              Text(
                                msg['message'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              timeago.format(date),
                              style: TextStyle(
                                color: isMe ? Colors.blue[100] : Colors.grey[600],
                                fontSize: 10,
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
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
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
                  Expanded(
                    child: TextField(
                      controller: _msgController,
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
                      onPressed: () => _sendMessage(),
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
