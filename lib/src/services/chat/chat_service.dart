import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../models/message.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _getChatRoomId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> sendMessage(String receiverId, String message) async {
    final currentUserId = _firebaseAuth.currentUser!.uid;
    final currentUserEmail = _firebaseAuth.currentUser!.email.toString();
    final timestamp = Timestamp.now();
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      type: 'text',
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(),
      newMessage.toMap(),
    );
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {
        'lastMessage': message,
        'lastMessageType': 'text',
        'lastMessageTime': timestamp,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> sendImageMessage(
      String receiverId, Uint8List imageBytes, String fileName) async {
    final currentUserId = _firebaseAuth.currentUser!.uid;
    final currentUserEmail = _firebaseAuth.currentUser!.email.toString();
    final timestamp = Timestamp.now();
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final ref = _storage.ref().child('chat_media/$chatRoomId/$fileName');
    await ref.putData(imageBytes);
    final mediaUrl = await ref.getDownloadURL();

    final newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: '📷 Фото',
      timestamp: timestamp,
      type: 'image',
      mediaUrl: mediaUrl,
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(),
      newMessage.toMap(),
    );
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {
        'lastMessage': '📷 Фото',
        'lastMessageType': 'image',
        'lastMessageTime': timestamp,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> sendStickerMessage(String receiverId, String stickerEmoji) async {
    final currentUserId = _firebaseAuth.currentUser!.uid;
    final currentUserEmail = _firebaseAuth.currentUser!.email.toString();
    final timestamp = Timestamp.now();
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: stickerEmoji,
      timestamp: timestamp,
      type: 'sticker',
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(),
      newMessage.toMap(),
    );
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {
        'lastMessage': stickerEmoji,
        'lastMessageType': 'sticker',
        'lastMessageTime': timestamp,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Stream<QuerySnapshot> getLastMessage(String userId, String otherUserId) {
    final chatRoomId = _getChatRoomId(userId, otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    final chatRoomId = _getChatRoomId(userId, otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Stream of chatRoom docs for a user, ordered by last message time
  Stream<QuerySnapshot> getUserChatRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}
