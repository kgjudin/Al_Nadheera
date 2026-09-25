class ChatMessage {
  final String id;
  final String siteId;
  final String senderId;
  final String? message;
  final String messageType; // 'text' or 'image'
  final String? mediaUrl;
  final DateTime createdAt;
  final String? senderEmail; // Joined from auth.users (if possible) or derived

  ChatMessage({
    required this.id,
    required this.siteId,
    required this.senderId,
    this.message,
    required this.messageType,
    this.mediaUrl,
    required this.createdAt,
    this.senderEmail,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      siteId: json['site_id'],
      senderId: json['sender_id'],
      message: json['message'],
      messageType: json['message_type'] ?? 'text',
      mediaUrl: json['media_url'],
      createdAt: DateTime.parse(json['created_at']),
      senderEmail: json['sender_email'],
    );
  }
}
