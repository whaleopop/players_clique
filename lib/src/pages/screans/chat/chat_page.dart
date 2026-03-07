import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/messages/chat_bubble.dart';
import 'package:players_clique/src/pages/screans/profile_sub_screen/profile_player.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:players_clique/src/services/chat/chat_service.dart';
import 'package:provider/provider.dart';

const List<String> _stickers = [
  'stickers/стикер1.png',
  'stickers/стикер2.png',
  'stickers/стикер 3 копия.png',
  'stickers/стикер4 копия.png',
  'stickers/стикер 5 копия.png',
  'stickers/стикер6копия.png',
  'stickers/стикер 7 копия.png',
  'stickers/стикер67 копия.png',
  'stickers/стикер 99 копия.png',
  'stickers/стикер 999 копия.png',
  'stickers/стикер555 копия.png',
  'stickers/алелеле копия.png',
  'stickers/алинаааа копия.png',
  'stickers/ангелека копия.png',
  'stickers/аринга2 копия.png',
  'stickers/аринеее копия.png',
  'stickers/вига копия.png',
  'stickers/виккаа копия.png',
  'stickers/всеее копия.png',
  'stickers/дианга копия.png',
  'stickers/дианна копия.png',
  'stickers/дидана.png',
  'stickers/йааааа копия.png',
  'stickers/квартиииры копия.png',
  'stickers/крисис копия.png',
  'stickers/крисссс копия.png',
  'stickers/михааааа копия.png',
  'stickers/мишиша копия.png',
  'stickers/онооо копия.png',
  'stickers/яяяяяя копия.png',
];

class ChatPage extends StatefulWidget {
  final String receiveruserEmail;
  final String receiverUserID;

  const ChatPage({
    super.key,
    required this.receiveruserEmail,
    required this.receiverUserID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  bool _showStickers = false;
  bool _isSending = false;
  String? _avatarUrl;
  String? _displayName;
  Map<String, dynamic>? _replyToData;

  /// Last read timestamp of the receiver — used to determine ✓✓ status.
  Timestamp? _receiverLastRead;
  StreamSubscription<DocumentSnapshot>? _chatRoomSub;

  /// Pagination: number of messages to load.
  int _messageLimit = 40;
  bool _loadingOlderMessages = false;

  /// Cached messages stream — only recreated when _messageLimit changes.
  late Stream<QuerySnapshot> _messagesStream;

  // ── Static in-memory caches (survive navigation back/forth) ────────────────
  /// Scroll position per chatRoomId.
  static final Map<String, double> _savedScrollPositions = {};
  /// Last known message docs per chatRoomId — shown instantly before Firestore responds.
  static final Map<String, List<QueryDocumentSnapshot>> _cachedDocs = {};
  // ───────────────────────────────────────────────────────────────────────────

  String get _chatRoomId {
    final ids = [widget.receiverUserID, _firebaseAuth.currentUser!.uid]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessages(
      widget.receiverUserID,
      _firebaseAuth.currentUser!.uid,
      limit: _messageLimit,
    );
    _loadReceiverInfo();
    _markAsRead();
    _subscribeToChatRoom();
    _scrollController.addListener(_onScroll);

    // Restore saved scroll position after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScrollPosition());
  }

  @override
  void dispose() {
    // Save scroll position before leaving.
    if (_scrollController.hasClients) {
      _savedScrollPositions[_chatRoomId] = _scrollController.position.pixels;
    }
    _chatRoomSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients) return;
    final saved = _savedScrollPositions[_chatRoomId];
    if (saved != null) {
      // Restore to where user was.
      _scrollController.jumpTo(
        saved.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    } else {
      // First open — jump to bottom.
      _scrollToBottom();
    }
  }

  void _subscribeToChatRoom() {
    _chatRoomSub = _chatService
        .getChatRoomStream(_firebaseAuth.currentUser!.uid, widget.receiverUserID)
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      final receiverLastRead =
          data['lastRead_${widget.receiverUserID}'] as Timestamp?;
      setState(() => _receiverLastRead = receiverLastRead);
    });
  }

  Future<void> _markAsRead() async {
    await _chatService.markAsRead(_chatRoomId, _firebaseAuth.currentUser!.uid);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 80 && !_loadingOlderMessages) {
      setState(() {
        _loadingOlderMessages = true;
        _messageLimit += 30;
        _messagesStream = _chatService.getMessages(
          widget.receiverUserID,
          _firebaseAuth.currentUser!.uid,
          limit: _messageLimit,
        );
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _loadingOlderMessages = false);
      });
    }
  }

  Future<void> _loadReceiverInfo() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final fio = await authService.getUserField(widget.receiverUserID, 'fio');
    final photo = await authService.getUserField(widget.receiverUserID, 'photourl');
    if (mounted) {
      setState(() {
        _displayName = fio ?? widget.receiveruserEmail;
        _avatarUrl = photo;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final reply = _replyToData;
    setState(() {
      _isSending = true;
      _replyToData = null;
    });
    try {
      await _chatService.sendMessage(
        widget.receiverUserID,
        text,
        replyToId: reply?['id'] as String?,
        replyToText: reply?['text'] as String?,
        replyToSenderName: reply?['senderName'] as String?,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendImageMessage(
        widget.receiverUserID,
        file.bytes!,
        file.name,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendSticker(String assetPath) async {
    setState(() => _showStickers = false);
    await _chatService.sendStickerMessage(widget.receiverUserID, assetPath);
  }

  void _showMessageOptions(DocumentSnapshot doc, String type, String message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.reply_outlined, color: Color(0xFF366837)),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() {
                  _replyToData = {
                    'id': doc.id,
                    'text': type == 'image' ? '📷 Фото' : message,
                    'senderName': isMe ? 'Вы' : (_displayName ?? 'Пользователь'),
                  };
                });
              },
            ),
            if (isMe && type == 'text')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _editMessage(doc, message);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Удалить',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _deleteMessage(doc);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editMessage(DocumentSnapshot doc, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Редактировать сообщение'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF366837)),
            onPressed: () async {
              Navigator.pop(context);
              final newText = ctrl.text.trim();
              if (newText.isEmpty || newText == currentText) return;
              await FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .doc(doc.id)
                  .update({'message': newText, 'edited': true});
            },
            child: const Text('Сохранить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .collection('messages')
        .doc(doc.id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        titleSpacing: 0,
        elevation: 0.5,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Profile_Player(uid: widget.receiverUserID),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                    ? NetworkImage(_avatarUrl!) as ImageProvider
                    : null,
                backgroundColor: Colors.lightBlue.shade100,
                child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                _displayName ?? widget.receiveruserEmail,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_replyToData != null) _buildReplyBar(),
          _buildInputBar(),
          if (_showStickers) _buildStickerPanel(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        // Use live docs if available, otherwise fall back to cache (instant reopen).
        final List<QueryDocumentSnapshot> docs;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          docs = snapshot.data!.docs;
          _cachedDocs[_chatRoomId] = docs; // update cache
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          docs = _cachedDocs[_chatRoomId] ?? [];
          if (docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
        } else {
          docs = [];
        }

        if (docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final pos = _scrollController.position;
              if (pos.maxScrollExtent - pos.pixels < 200) {
                _scrollToBottom();
              }
            }
          });
        }

        return Column(
          children: [
            if (_loadingOlderMessages)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildMessageItem(docs[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _firebaseAuth.currentUser!.uid;
    final type = data['type'] as String? ?? 'text';
    final mediaUrl = data['mediaUrl'] as String?;
    final message = data['message'] as String? ?? '';
    final edited = data['edited'] as bool? ?? false;
    DateTime? time;
    Timestamp? msgTimestamp;
    if (data['timestamp'] != null) {
      msgTimestamp = data['timestamp'] as Timestamp;
      time = msgTimestamp.toDate();
    }

    // Determine read status for my messages.
    bool? isRead;
    if (isMe && msgTimestamp != null && _receiverLastRead != null) {
      isRead = _receiverLastRead!.compareTo(msgTimestamp) >= 0;
    } else if (isMe) {
      isRead = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!) as ImageProvider
                  : null,
              backgroundColor: Colors.lightBlue.shade100,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _showMessageOptions(document, type, message, isMe),
            child: ChatBubble(
              message: message,
              isMe: isMe,
              type: type,
              mediaUrl: mediaUrl,
              time: time,
              edited: edited,
              isRead: isRead,
              replyToText: data['replyToText'] as String?,
              replyToSenderName: data['replyToSenderName'] as String?,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: const Color(0xFF366837)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyToData!['senderName'] as String,
                  style: const TextStyle(
                    color: Color(0xFF366837),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _replyToData!['text'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
            onPressed: () => setState(() => _replyToData = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showStickers = !_showStickers),
              icon: Icon(
                _showStickers ? Icons.keyboard : Icons.sticky_note_2_outlined,
                color: const Color(0xFF366837),
              ),
            ),
            IconButton(
              onPressed: _isSending ? null : _sendImage,
              icon: const Icon(Icons.image_outlined, color: Color(0xFF366837)),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Напишите сообщение...',
                  hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : const Color(0xFF366837),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerPanel() {
    return Container(
      height: 260,
      color: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _stickers.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendSticker(_stickers[index]),
            child: Image.asset(
              _stickers[index],
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}
