class ChatMessage {
  final String id;
  final String? siteId;
  final String senderId;
  final String? receiverId;
  final String message;
  final String messageType; // 'text', 'image', 'file', 'audio'
  final String? mediaUrl;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final Map<String, dynamic>? reactions; // e.g. {'👍': ['userId1'], '❤️': ['userId2']}
  final bool isStarred;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    this.siteId,
    required this.senderId,
    this.receiverId,
    required this.message,
    this.messageType = 'text',
    this.mediaUrl,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.reactions,
    this.isStarred = false,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString(),
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString(),
      message: json['message'] ?? '',
      messageType: json['message_type'] ?? 'text',
      mediaUrl: json['media_url'],
      replyToId: json['reply_to_id']?.toString(),
      replyToText: json['reply_to_text'],
      replyToSenderName: json['reply_to_sender_name'],
      reactions: json['reactions'] is Map ? Map<String, dynamic>.from(json['reactions']) : null,
      isStarred: json['is_starred'] ?? false,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (siteId != null) 'site_id': siteId,
      if (receiverId != null) 'receiver_id': receiverId,
      'sender_id': senderId,
      'message': message,
      'message_type': messageType,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
      if (reactions != null) 'reactions': reactions,
      'is_starred': isStarred,
    };
  }
}
