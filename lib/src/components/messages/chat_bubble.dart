import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String type;
  final String? mediaUrl;
  final DateTime? time;
  final bool edited;
  final String? replyToText;
  final String? replyToSenderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.type = 'text',
    this.mediaUrl,
    this.time,
    this.edited = false,
    this.replyToText,
    this.replyToSenderName,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'sticker':
        return _buildStickerBubble();
      case 'image':
        return _buildImageBubble(context);
      default:
        return _buildTextBubble(context);
    }
  }

  Widget _buildTextBubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF0071BC) : cs.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyToText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.18)
                    : cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: isMe ? Colors.white70 : const Color(0xFF0071BC),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyToSenderName != null)
                    Text(
                      replyToSenderName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white70 : const Color(0xFF0071BC),
                      ),
                    ),
                  Text(
                    replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe
                          ? Colors.white60
                          : cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: isMe ? Colors.white : cs.onSurface,
              height: 1.3,
            ),
          ),
          if (time != null || edited) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (edited)
                  Text(
                    'изм. ',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white54 : cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                if (time != null)
                  Text(
                    _formatTime(time!),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white54 : cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (mediaUrl != null) {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(
                child: Image.network(
                  mediaUrl!,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
                ),
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        child: mediaUrl != null
            ? Image.network(
                mediaUrl!,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 220,
                    height: 160,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 220,
                  height: 160,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              )
            : Container(width: 220, height: 160, color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildStickerBubble() {
    return Image.asset(
      message,
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(message, style: const TextStyle(fontSize: 48)),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
