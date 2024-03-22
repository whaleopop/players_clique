import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat/chat_service.dart';

class MessageProfile extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final ImageProvider iconProfile;
  final String senderId;
  final String receiverId;
  final ChatService chatService; // Make chatService a parameter

  MessageProfile({
    Key? key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.chatService, // Pass chatService when creating MessageProfile
  }) : super(key: key);

  @override
  _MessageProfileState createState() => _MessageProfileState();
}

class _MessageProfileState extends State<MessageProfile> {

  late Stream<QuerySnapshot> messageStream;

  @override
  void initState() {
    super.initState();
    messageStream = getLastMessage(widget.senderId, widget.receiverId);
  }

  Stream<QuerySnapshot> getLastMessage(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");
    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          CircleAvatar(
          radius: 30,
          backgroundImage: widget.iconProfile,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
            widget.text,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
              StreamBuilder<QuerySnapshot>(
                stream: messageStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading..');
                  }
                  if (snapshot.hasError) {
                    return Text('Error ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    var messages = snapshot.data!.docs;
                    if (messages.isNotEmpty) { // Check if the list is not empty
                      return Text(messages.first["message"]);
                    } else {
                      return Text('Нет сообщений'); // Optionally, display a message when no messages are found
                    }
                  }
                  return Container();
                },
              )

            ],
        ),
      ),
      ],
    ),)
    ,
    );
  }
}
