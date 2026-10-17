import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isGroupChat;
  final String? senderName;
  final Function(ChatMessage)? onReply;
  final Function(ChatMessage)? onDelete;
  final Function(ChatMessage, String emoji)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroupChat = false,
    this.senderName,
    this.onReply,
    this.onDelete,
    this.onReact,
  });

  void _openFullScreenImage(BuildContext context, String imageUrl, String? caption) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.7),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              caption != null && caption.isNotEmpty && caption != 'Photo'
                  ? caption
                  : 'Photo',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open file link')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getDocumentIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_rounded;
    if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) return Icons.article_rounded;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getDocumentColor(String? fileName) {
    if (fileName == null) return Colors.indigo;
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Colors.red.shade700;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Colors.green.shade700;
    if (['doc', 'docx', 'txt'].contains(ext)) return Colors.blue.shade700;
    if (['zip', 'rar', '7z'].contains(ext)) return Colors.amber.shade800;
    return Colors.indigo;
  }

  void _showContextMenu(BuildContext context) {
    final hasMedia = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Emoji Reaction Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (onReact != null) onReact!(message, emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                if (onReply != null) onReply!(message);
              },
            ),
            if (hasMedia)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open Attachment'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (message.messageType == 'image') {
                    _openFullScreenImage(context, message.mediaUrl!, message.message);
                  } else {
                    _openUrl(context, message.mediaUrl!);
                  }
                },
              ),
            if (message.message.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.message));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (onDelete != null) onDelete!(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final type = message.messageType;
    final mediaUrl = message.mediaUrl;

    if (type == 'image' && mediaUrl != null && mediaUrl.isNotEmpty) {
      final caption = message.message.trim();
      final hasCaption = caption.isNotEmpty && caption.toLowerCase() != 'photo';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openFullScreenImage(context, mediaUrl, caption),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                  maxWidth: 280,
                ),
                color: Colors.white,
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final total = loadingProgress.expectedTotalBytes;
                    final loaded = loadingProgress.cumulativeBytesLoaded;
                    return Container(
                      height: 180,
                      color: const Color(0xFFF0F2F5),
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: total != null ? loaded / total : null,
                        strokeWidth: 2.5,
                        color: const Color(0xFF00A884),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 140,
                      color: Colors.grey.shade200,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                          SizedBox(height: 6),
                          Text('Image failed to load', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (hasCaption) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
        ],
      );
    }

    if ((type == 'document' || type == 'file') && mediaUrl != null && mediaUrl.isNotEmpty) {
      final displayName = message.fileName ?? (message.message.isNotEmpty ? message.message : 'Document');
      final icon = _getDocumentIcon(displayName);
      final iconColor = _getDocumentColor(displayName);
      final sizeStr = _formatFileSize(message.fileSize);
      final ext = displayName.contains('.') ? displayName.split('.').last.toUpperCase() : 'FILE';
      final subtitle = [ext, if (sizeStr.isNotEmpty) sizeStr].join(' • ');

      return InkWell(
        onTap: () => _openUrl(context, mediaUrl),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.black.withOpacity(0.04) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.download_for_offline_rounded, color: Theme.of(context).colorScheme.primary, size: 26),
            ],
          ),
        ),
      );
    }

    if (type == 'location') {
      final locText = message.message.isNotEmpty ? message.message : 'Site Location';
      final mapUrl = mediaUrl ?? 'https://maps.google.com/?q=${Uri.encodeComponent(locText)}';

      return InkWell(
        onTap: () => _openUrl(context, mapUrl),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.black.withOpacity(0.04) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shared Location',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      locText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      );
    }

    // Default: Plain Text
    return Text(
      message.message,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.jm().format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Chat Sender Name
              if (!isMe && isGroupChat && senderName != null) ...[
                Text(
                  senderName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C81),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // Reply Preview Box inside bubble
              if (message.replyToText != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.black.withOpacity(0.05)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.replyToSenderName != null)
                        Text(
                          message.replyToSenderName!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Message Body / Image / Document / Location Content
              _buildContent(context),
              const SizedBox(height: 4),

              // Time & Read Status Ticks
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: message.isRead ? const Color(0xFF34B7F1) : Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
