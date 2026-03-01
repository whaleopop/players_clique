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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Нет пользователей'));
                  }

                  final currentUid = _auth.currentUser!.uid;
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['uid'] == currentUid) return false;
                    if (_searchQuery.isEmpty) return true;
                    final fio = (data['fio'] as String? ?? '').toLowerCase();
                    return fio.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Никого не найдено',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final uid = data['uid'] as String? ?? docs[index].id;
                      final photoUrl = data['photourl'] as String? ?? '';
                      final fio = data['fio'] as String? ?? '';

                      return MessageProfile(
                        iconProfile: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : const AssetImage('assets/image/sportman1.png') as ImageProvider,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                receiveruserEmail: fio,
                                receiverUserID: uid,
                              ),
                            ),
                          );
                        },
                        text: fio,
                        senderId: uid,
                        receiverId: currentUid,
                        chatService: ChatService(),
                      );
                    },
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
