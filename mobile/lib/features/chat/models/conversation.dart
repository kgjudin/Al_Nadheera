enum ConversationType { personal, siteGroup, generalGroup }

class Conversation {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final ConversationType type;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;

  Conversation({
    required this.id,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    required this.type,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? avatarUrl,
    ConversationType? type,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? isPinned,
    bool? isMuted,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
