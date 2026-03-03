import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';

import '../../models/post.dart';
import '../notification/notification_sender.dart';

class PostService with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to create a new post
  Future<void> createPost(Post post) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final docRef = await _firestore
          .collection('posts')
          .doc(post.userId)
          .collection("post")
          .add(post.toMap());
      notifyListeners();
      // Notify friends about the new post (fire-and-forget).
      NotificationSender.sendPostNotification(
        authorId: post.userId,
        postTitle: post.namePost,
        postDesc: post.descPost,
        postId: docRef.id,
      );
    } else {
      throw Exception('User not logged in');
    }
  }

  // Method to get all posts
  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Object?>> getPostsbyUser() {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return _firestore
          .collection('posts').doc(user.uid).collection("post")
          .orderBy('timestamp', descending: true)
          .snapshots();
    }else{
      throw Exception('User not logged in');
    }
  }

  // Method to delete a post
  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
    notifyListeners(); // Notify listeners to update UI
  }

  // Method to update a post
  Future<void> updatePost(
      String postId, String content, String imageUrl) async {
    await _firestore.collection('posts').doc(postId).update({
      'content': content,
      'imageUrl': imageUrl,
    });
    notifyListeners(); // Notify listeners to update UI
  }

  // Method to get a single post by ID
  Stream<DocumentSnapshot> getPostById(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots();
  }
}
