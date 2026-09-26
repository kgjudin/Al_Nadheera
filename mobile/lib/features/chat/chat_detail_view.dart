import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _currentUserId;
  String? _avatarUrl;

  ChatMessage? _replyingToMessage;

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

          // WhatsApp Style Message Input
          MessageInputBar(
            controller: _messageController,
            onSend: _sendMessage,
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
