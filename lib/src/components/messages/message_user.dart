import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat/chat_service.dart';

class MessageProfile extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final ImageProvider iconProfile;
  /// The other user's ID.
  final String senderId;
  /// The current user's ID.
  final String receiverId;
  final ChatService chatService;

  const MessageProfile({
    super.key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.chatService,
  });

  @override
  _MessageProfileState createState() => _MessageProfileState();
}

class _MessageProfileState extends State<MessageProfile> {
  late Stream<QuerySnapshot> _messageStream;
  late Stream<bool> _unreadStream;

  @override
  void initState() {
    super.initState();
    final chatRoomId =
        ([widget.senderId, widget.receiverId]..sort()).join('_');
    _messageStream = widget.chatService.getLastMessage(
      widget.senderId,
      widget.receiverId,
    );
    _unreadStream = widget.chatService.getHasUnreadStream(
      chatRoomId,
      widget.receiverId,
    );
  }

  String _previewText(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'text';
    switch (type) {
      case 'image':
        return '📷 Фото';
      case 'sticker':
        return data['message'] as String? ?? '🎉';
      default:
        return data['message'] as String? ?? '';
    }
  }

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with unread dot badge
            StreamBuilder<bool>(
              stream: _unreadStream,
              builder: (context, snap) {
                final hasUnread = snap.data ?? false;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: widget.iconProfile,
                      onBackgroundImageError: (_, __) {},
                      backgroundColor: const Color(0xFFCCE5CC),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC84926),
                            shape: BoxShape.circle,
                            border: Border.all(color: scaffoldBg, width: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messageStream,
                builder: (context, snapshot) {
                  String preview = 'Нет сообщений';
                  String time = '';

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final doc = snapshot.data!.docs.first;
                    final data = doc.data() as Map<String, dynamic>;
                    preview = _previewText(data);
                    if (data['timestamp'] != null) {
                      time = _formatTime(data['timestamp'] as Timestamp);
                    }
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.text,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            StreamBuilder<bool>(
                              stream: _unreadStream,
                              builder: (context, unreadSnap) {
                                final hasUnread = unreadSnap.data ?? false;
                                return Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: hasUnread
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.55),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
