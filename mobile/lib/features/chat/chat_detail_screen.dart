import 'package:flutter/material.dart';
import 'chat_detail_view.dart';

class ChatDetailScreen extends StatelessWidget {
  final String title;
  final String entityId;
  final bool isGroupChat;
  final String? avatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.title,
    required this.entityId,
    required this.isGroupChat,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChatDetailView(
      title: title,
      entityId: entityId,
      isGroupChat: isGroupChat,
      avatarUrl: avatarUrl,
    );
  }
}
