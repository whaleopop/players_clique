import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/services/chat/chat_service.dart';

import '../../components/messages/message_user.dart';
import 'chat/chat_page.dart';

class Message_Page extends StatefulWidget {
  @override
  _Message_Page createState() => _Message_Page();
}

class _Message_Page extends State<Message_Page> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser!.uid;
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Найти пользователя...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildRecentChats(currentUid)
                  : _buildSearchResults(currentUid),
            ),
          ],
        ),
      ),
    );
  }

  // --- Recent chats: все chat_rooms где участвует юзер ---
  Widget _buildRecentChats(String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = List.of(snapshot.data?.docs ?? []);
        // Сортируем по lastMessageTime (новые сверху), старые чаты без поля — в конец
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['lastMessageTime'] as Timestamp?;
          final bTime = bData['lastMessageTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Нет сообщений',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Найдите пользователя чтобы написать',
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildChatRoomTile(docs[i], currentUid),
        );
      },
    );
  }

  Widget _buildChatRoomTile(DocumentSnapshot chatRoom, String currentUid) {
    final data = chatRoom.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUid =
        participants.firstWhere((uid) => uid != currentUid, orElse: () => '');
    if (otherUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final user = snap.data!.data() as Map<String, dynamic>? ?? {};
        final fio = user['fio'] as String? ?? '';
        final photo = user['photourl'] as String? ?? '';
        return MessageProfile(
          iconProfile: photo.isNotEmpty
              ? NetworkImage(photo)
              : const AssetImage('assets/image/sportman1.png') as ImageProvider,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                receiveruserEmail: fio,
                receiverUserID: otherUid,
              ),
            ),
          ),
          text: fio,
          senderId: otherUid,
          receiverId: currentUid,
          chatService: ChatService(),
        );
      },
    );
  }

  // --- Search: show all users matching query ---
  Widget _buildSearchResults(String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['uid'] == currentUid) return false;
          final fio = (d['fio'] as String? ?? '').toLowerCase();
          return fio.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text('Никого не найдено',
                style: TextStyle(color: Colors.grey.shade400)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final uid = d['uid'] as String? ?? docs[i].id;
            final fio = d['fio'] as String? ?? '';
            final photo = d['photourl'] as String? ?? '';
            return MessageProfile(
              iconProfile: photo.isNotEmpty
                  ? NetworkImage(photo)
                  : const AssetImage('assets/image/sportman1.png')
                      as ImageProvider,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    receiveruserEmail: fio,
                    receiverUserID: uid,
                  ),
                ),
              ),
              text: fio,
              senderId: uid,
              receiverId: currentUid,
              chatService: ChatService(),
            );
          },
        );
      },
    );
  }
}
