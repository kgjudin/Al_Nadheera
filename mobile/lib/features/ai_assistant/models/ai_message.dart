class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  AiMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  AiMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return AiMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
