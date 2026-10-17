import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/site_model.dart';
import 'models/chat_message.dart';
import 'services/presence_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input_bar.dart';

class ChatDetailView extends StatefulWidget {
  final String title;
  final String entityId;
  final bool isGroupChat;
  final String? avatarUrl;

  const ChatDetailView({
    super.key,
    required this.title,
    required this.entityId,
    required this.isGroupChat,
    this.avatarUrl,
  });

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView> {
  final TextEditingController _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  String? _currentUserId;
  String? _avatarUrl;
  ChatMessage? _replyingToMessage;

  bool _isUploading = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;
    _currentUserId = _supabase.auth.currentUser?.id;
    PresenceService.instance.initialize();
    _markMessagesAsRead();
    if (_avatarUrl == null && !widget.isGroupChat) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final res = await _supabase
          .from('employees')
          .select('profile_image_url')
          .eq('id', widget.entityId)
          .maybeSingle();
      if (mounted && res != null && res['profile_image_url'] != null) {
        setState(() {
          _avatarUrl = res['profile_image_url']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;
    try {
      if (!widget.isGroupChat) {
        await _supabase
            .from('chat_messages')
            .update({'is_read': true})
            .eq('receiver_id', _currentUserId!)
            .eq('sender_id', widget.entityId)
            .eq('is_read', false);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('site_last_read_${widget.entityId}', DateTime.now().toIso8601String());
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    final replyMessage = _replyingToMessage;

    setState(() {
      _replyingToMessage = null;
    });

    _messageController.clear();

    try {
      final messageData = {
        'sender_id': _currentUserId,
        'message': text,
        'message_type': 'text',
        if (widget.isGroupChat) 'site_id': widget.entityId,
        if (!widget.isGroupChat) 'receiver_id': widget.entityId,
        if (replyMessage != null) ...{
          'reply_to_id': replyMessage.id,
          'reply_to_text': replyMessage.message,
          'reply_to_sender_name': replyMessage.senderId == _currentUserId ? 'You' : widget.title,
        },
      };

      await _supabase.from('chat_messages').insert(messageData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendAttachmentMessage({
    required String messageType,
    required String mediaUrl,
    String? caption,
    String? fileName,
    int? fileSize,
  }) async {
    if (_currentUserId == null) return;
    final replyMessage = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    try {
      final messageData = {
        'sender_id': _currentUserId,
        if (widget.isGroupChat) 'site_id': widget.entityId,
        if (!widget.isGroupChat) 'receiver_id': widget.entityId,
        'message': caption != null && caption.trim().isNotEmpty
            ? caption.trim()
            : (messageType == 'image' ? 'Photo' : (fileName ?? 'Attachment')),
        'message_type': messageType,
        'media_url': mediaUrl,
        if (fileName != null) 'file_name': fileName,
        if (fileSize != null) 'file_size': fileSize,
        if (replyMessage != null) ...{
          'reply_to_id': replyMessage.id,
          'reply_to_text': replyMessage.message,
          'reply_to_sender_name': replyMessage.senderId == _currentUserId ? 'You' : widget.title,
        },
      };

      await _supabase.from('chat_messages').insert(messageData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending attachment: $e')),
        );
      }
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
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _uploadAndSend({
    required Uint8List bytes,
    required String fileName,
    required String messageType,
    String? caption,
    int? fileSize,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading $fileName...';
    });

    try {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
      final mimeType = _getMimeType(fileName);
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$ext';
      final storagePath = 'chat/${widget.entityId}/$uniqueName';

      await _supabase.storage.from('chat-media').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );

      final mediaUrl = _supabase.storage.from('chat-media').getPublicUrl(storagePath);

      await _sendAttachmentMessage(
        messageType: messageType,
        mediaUrl: mediaUrl,
        caption: caption,
        fileName: fileName,
        fileSize: fileSize ?? bytes.length,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
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

  Future<void> _previewAndSendImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final captionController = TextEditingController();

    final shouldSend = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Send Photo',
                        style: TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(sheetCtx, false),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetCtx).size.height * 0.42,
                    maxWidth: double.infinity,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: captionController,
                          style: const TextStyle(
                            color: Color(0xFF2C3E50),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: const Color(0xFF00A884),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF0F2F5),
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A884),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A884),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(sheetCtx, true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSend == true) {
      final caption = captionController.text.trim();
      await _uploadAndSend(
        bytes: bytes,
        fileName: file.name,
        messageType: 'image',
        caption: caption,
      );
    }
  }

  Future<void> _handleDocumentSelection() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'zip', 'rar'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null && !kIsWeb && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file')),
          );
        }
        return;
      }

      if (!mounted) return;

      final captionController = TextEditingController();

      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.insert_drive_file_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Send Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_present_rounded, color: Colors.indigo, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            _formatBytes(fileBytes!.length),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  hintText: 'Add an optional note...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (shouldSend == true) {
        await _uploadAndSend(
          bytes: fileBytes,
          fileName: file.name,
          messageType: 'document',
          caption: captionController.text.trim(),
          fileSize: fileBytes.length,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _handleLocationSelection() async {
    try {
      final apiService = ApiService();
      final sites = await apiService.getSites().catchError((_) => <Site>[]);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Share Site Location',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (sites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No sites available to share.'),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: sites.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final site = sites[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.business_rounded, color: Colors.green),
                            ),
                            title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              site.location ?? 'No address registered',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.send_rounded, color: Color(0xFF00A884), size: 20),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              final locDesc = site.location != null && site.location!.isNotEmpty
                                  ? '${site.name} - ${site.location}'
                                  : site.name;
                              final mapUrl = 'https://maps.google.com/?q=${Uri.encodeComponent(site.location ?? site.name)}';
                              await _sendAttachmentMessage(
                                messageType: 'location',
                                mediaUrl: mapUrl,
                                caption: locDesc,
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sites: $e')),
        );
      }
    }
  }

  void _handleAttachment(String type) async {
    if (_isUploading) return;

    if (type == 'camera') {
      try {
        final xfile = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (xfile != null) {
          await _previewAndSendImage(xfile);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Camera error: $e')),
          );
        }
      }
    } else if (type == 'gallery') {
      try {
        final xfile = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (xfile != null) {
          await _previewAndSendImage(xfile);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gallery error: $e')),
          );
        }
      }
    } else if (type == 'document') {
      await _handleDocumentSelection();
    } else if (type == 'location') {
      await _handleLocationSelection();
    }
  }

  void _onReply(ChatMessage message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  void _onDelete(ChatMessage message) async {
    try {
      await _supabase.from('chat_messages').delete().eq('id', message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surface,
              backgroundImage: (!widget.isGroupChat && _avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: (!widget.isGroupChat && _avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? null
                  : Icon(
                      widget.isGroupChat ? Icons.business_rounded : Icons.person_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (widget.isGroupChat)
                    Text(
                      'Site Group Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      ),
                    )
                  else
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: PresenceService.instance.onlineUsersNotifier,
                      builder: (context, onlineIds, _) {
                        final isOnline = PresenceService.instance.isUserOnline(widget.entityId);
                        return Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF25D366) : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: isOnline ? const Color(0xFF25D366) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Stream Messages
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.isGroupChat
                  ? _supabase
                      .from('chat_messages')
                      .stream(primaryKey: ['id'])
                      .eq('site_id', widget.entityId)
                      .order('created_at', ascending: true)
                  : _supabase
                      .from('chat_messages')
                      .stream(primaryKey: ['id'])
                      .order('created_at', ascending: true)
                      .map((messages) => messages.where((msg) {
                            final sender = msg['sender_id'];
                            final receiver = msg['receiver_id'];
                            return (sender == _currentUserId && receiver == widget.entityId) ||
                                   (sender == widget.entityId && receiver == _currentUserId);
                          }).toList()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final rawMessages = snapshot.data ?? [];
                if (rawMessages.any((m) => m['receiver_id'] == _currentUserId && m['is_read'] != true)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });
                }

                if (rawMessages.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4EAF7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Messages are end-to-end encrypted for internal AL NADHEERA communications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xB3000000)),
                      ),
                    ),
                  );
                }

                final messages = rawMessages.map((m) => ChatMessage.fromJson(m)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUserId;

                    return MessageBubble(
                      message: msg,
                      isMe: isMe,
                      isGroupChat: widget.isGroupChat,
                      senderName: isMe ? 'You' : widget.title,
                      onReply: _onReply,
                      onDelete: _onDelete,
                    );
                  },
                );
              },
            ),
          ),

          // Upload progress bar
          if (_isUploading)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadStatus.isNotEmpty ? _uploadStatus : 'Uploading attachment...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // WhatsApp Style Message Input
          MessageInputBar(
            controller: _messageController,
            onSend: _sendMessage,
            onAttachmentSelected: _handleAttachment,
            isUploading: _isUploading,
            replySenderName: _replyingToMessage != null
                ? (_replyingToMessage!.senderId == _currentUserId ? 'You' : widget.title)
                : null,
            replyMessageText: _replyingToMessage?.message,
            onCancelReply: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
