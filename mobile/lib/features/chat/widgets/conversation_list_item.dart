import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';

class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGroup = conversation.type != ConversationType.personal;

    String timeText = '';
    if (conversation.lastMessageTime != null) {
      final now = DateTime.now();
      final date = conversation.lastMessageTime!;
      if (now.day == date.day && now.month == date.month && now.year == date.year) {
        timeText = DateFormat.jm().format(date);
      } else {
        timeText = DateFormat('dd/MM/yy').format(date);
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Profile Avatar with Online Badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isGroup
                      ? theme.colorScheme.secondary.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.15),
                  child: isGroup
                      ? Icon(Icons.business_rounded, color: theme.colorScheme.secondary)
                      : Text(
                          conversation.title.isNotEmpty ? conversation.title[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
                if (!isGroup && conversation.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366), // WhatsApp online green
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: conversation.unreadCount > 0 ? theme.colorScheme.primary : Colors.grey.shade600,
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: conversation.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (conversation.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.push_pin_rounded, size: 14, color: Colors.grey.shade500),
                        ),
                      if (conversation.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
