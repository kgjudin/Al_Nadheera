import 'package:flutter/material.dart';
import 'reply_preview_bar.dart';

class MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String? replySenderName;
  final String? replyMessageText;
  final VoidCallback? onCancelReply;
  final Function(String attachmentType)? onAttachmentSelected;

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.replySenderName,
    this.replyMessageText,
    this.onCancelReply,
    this.onAttachmentSelected,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _showAttachmentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _buildAttachmentOption(
              context,
              icon: Icons.image_rounded,
              color: Colors.purple,
              label: 'Gallery',
              type: 'gallery',
            ),
            _buildAttachmentOption(
              context,
              icon: Icons.camera_alt_rounded,
              color: Colors.pink,
              label: 'Camera',
              type: 'camera',
            ),
            _buildAttachmentOption(
              context,
              icon: Icons.insert_drive_file_rounded,
              color: Colors.indigo,
              label: 'Document',
              type: 'document',
            ),
            _buildAttachmentOption(
              context,
              icon: Icons.location_on_rounded,
              color: Colors.green,
              label: 'Site Location',
              type: 'location',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String type,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (widget.onAttachmentSelected != null) {
          widget.onAttachmentSelected!(type);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replySenderName != null && widget.replyMessageText != null)
          ReplyPreviewBar(
            senderName: widget.replySenderName!,
            messageText: widget.replyMessageText!,
            onCancel: widget.onCancelReply ?? () {},
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            maxLines: 5,
                            minLines: 1,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                          onPressed: () => _showAttachmentModal(context),
                        ),
                        if (!_hasText)
                          IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                            onPressed: () => _showAttachmentModal(context),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A884), // WhatsApp green accent
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _hasText ? Icons.send_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _hasText ? widget.onSend : () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
