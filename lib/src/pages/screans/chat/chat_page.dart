import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/messages/chat_bubble.dart';
import 'package:players_clique/src/components/my_text_field.dart';
import 'package:players_clique/src/services/chat/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String receiveruserEmail;
  final String receiverUserID;

  const ChatPage({
    super.key,
    required this.receiveruserEmail,
    required this.receiverUserID,
  });

  @override
  State<ChatPage> createState() => _ChatPage();
}

class _ChatPage extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
          widget.receiverUserID, _messageController.text);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiveruserEmail),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder(stream: _chatService.getMessages(
        widget.receiverUserID, _firebaseAuth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error ${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading..');
          }

          return ListView(
            children: snapshot.data!.docs.map((document) =>
                _buildMessageItem(document)).toList(),
          );
        });
  }

  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    var aligment = (data['senderId'] == _firebaseAuth.currentUser!.uid)
        ? Alignment.centerRight :
    Alignment.centerLeft;

    return Container(
      alignment: aligment,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
            crossAxisAlignment: (data['senderId'] ==
                _firebaseAuth.currentUser!.uid)
                ? CrossAxisAlignment.end :
            CrossAxisAlignment.start,
            mainAxisAlignment: (data['senderId'] ==
                _firebaseAuth.currentUser!.uid)
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
        //Text(data['senderEmail']),
        ChatBubble(message: data['message'])


        ],
      ),
    ),);
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(child: MyTextField(controller: _messageController,
          obscureText: false,
          hintText: 'Напишите сообщение',
        ),
        ),
        IconButton(onPressed: sendMessage, icon: Icon(Icons.arrow_upward))
      ],
    );
  }

}
