import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/messages/chat_bubble.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:players_clique/src/services/chat/chat_service.dart';
import 'package:provider/provider.dart';

const List<Map<String, Object>> _stickerGroups = [
  {
    'name': 'Эмоции',
    'stickers': [
      '😀', '😂', '🥹', '😍', '🥳', '😎', '🤩', '😜',
      '😏', '🥺', '😤', '😡', '🤯', '😱', '🤔', '🙄',
    ],
  },
  {
    'name': 'Спорт',
    'stickers': [
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱',
      '🏋️', '🤸', '🏊', '🚴', '🧘', '🤼', '🥊', '🏆',
    ],
  },
  {
    'name': 'Игры',
    'stickers': [
      '🎮', '🕹️', '🃏', '🎲', '🧩', '👾', '🤖', '🦸',
      '🦹', '🐉', '⚔️', '🛡️', '✨', '🎯', '🎳', '🏅',
    ],
  },
  {
    'name': 'Прочее',
    'stickers': [
      '❤️', '🔥', '💯', '👍', '👎', '🙌', '💪', '🤝',
      '🎉', '💥', '⭐', '🌈', '🎵', '🍕', '🚀', '🌙',
    ],
  },
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

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  bool _showStickers = false;
  bool _isSending = false;
  String? _avatarUrl;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stickerGroups.length, vsync: this);
    _loadReceiverInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(widget.receiverUserID, text);
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

  Future<void> _sendSticker(String emoji) async {
    setState(() => _showStickers = false);
    await _chatService.sendStickerMessage(widget.receiverUserID, emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0071BC),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
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
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
          if (_showStickers) _buildStickerPanel(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(
        widget.receiverUserID,
        _firebaseAuth.currentUser!.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildMessageItem(docs[index]),
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
    DateTime? time;
    if (data['timestamp'] != null) {
      time = (data['timestamp'] as Timestamp).toDate();
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
          ChatBubble(
            message: message,
            isMe: isMe,
            type: type,
            mediaUrl: mediaUrl,
            time: time,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showStickers = !_showStickers),
              icon: Icon(
                _showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined,
                color: const Color(0xFF0071BC),
              ),
            ),
            IconButton(
              onPressed: _isSending ? null : _sendImage,
              icon: const Icon(Icons.image_outlined, color: Color(0xFF0071BC)),
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
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F4F8),
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
                  color: _isSending ? Colors.grey : const Color(0xFF0071BC),
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
      height: 280,
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0071BC),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0071BC),
            tabs: _stickerGroups
                .map((g) => Tab(text: g['name'] as String))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _stickerGroups.map((group) {
                final stickers = group['stickers'] as List;
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: stickers.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _sendSticker(stickers[index] as String),
                      child: Center(
                        child: Text(
                          stickers[index] as String,
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
