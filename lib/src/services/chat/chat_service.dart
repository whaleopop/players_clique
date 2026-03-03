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

  Future<void> sendMessage(
    String receiverId,
    String message, {
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
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

    final msgMap = newMessage.toMap();
    if (replyToId != null) {
      msgMap['replyToId'] = replyToId;
      msgMap['replyToText'] = replyToText;
      msgMap['replyToSenderName'] = replyToSenderName;
    }

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(),
      msgMap,
    );
    batch.set(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {
        'lastMessage': message,
        'lastMessageType': 'text',
        'lastMessageTime': timestamp,
        'lastSenderId': currentUserId,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    _checkMutualFriendship(currentUserId, receiverId, chatRoomId);
  }

  Future<void> _checkMutualFriendship(
      String senderId, String receiverId, String chatRoomId) async {
    final check = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: receiverId)
        .limit(1)
        .get();
    if (check.docs.isNotEmpty) {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(senderId), {
        'friends': FieldValue.arrayUnion([receiverId]),
      });
      batch.update(_firestore.collection('users').doc(receiverId), {
        'friends': FieldValue.arrayUnion([senderId]),
      });
      await batch.commit();
    }
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
        'lastSenderId': currentUserId,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    _checkMutualFriendship(currentUserId, receiverId, chatRoomId);
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
        'lastSenderId': currentUserId,
        'participants': [currentUserId, receiverId],
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    _checkMutualFriendship(currentUserId, receiverId, chatRoomId);
  }

  /// Mark chat as read by [userId] — updates lastRead_{userId} on chatRoom doc.
  Future<void> markAsRead(String chatRoomId, String userId) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set(
        {'lastRead_$userId': Timestamp.now()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Stream of the chatRoom document (used to track lastRead timestamps).
  Stream<DocumentSnapshot> getChatRoomStream(String userId, String otherUserId) {
    final chatRoomId = _getChatRoomId(userId, otherUserId);
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }

  /// Stream of whether [currentUserId] has unread messages in a chatRoom.
  Stream<bool> getHasUnreadStream(String chatRoomId, String currentUserId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final lastSenderId = data['lastSenderId'] as String?;
      if (lastSenderId == null || lastSenderId == currentUserId) return false;
      final lastMsgTime = data['lastMessageTime'] as Timestamp?;
      if (lastMsgTime == null) return false;
      final lastRead = data['lastRead_$currentUserId'] as Timestamp?;
      if (lastRead == null) return true;
      return lastMsgTime.compareTo(lastRead) > 0;
    });
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

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId,
      {int limit = 40}) {
    final chatRoomId = _getChatRoomId(userId, otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
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
