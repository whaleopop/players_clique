import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  profileListLoad(String uid, String field,List list) async {
    try {
      _firestore.collection('users').doc(uid).set({
        field: list,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }


  profileImageLoad(String uid, String photourl) async {
    try {
      _firestore.collection('users').doc(uid).set({
        'photourl': photourl
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }
  Future<List<String>> getUserList(String uid, String listfield) async {
    final DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (documentSnapshot.exists) {
      final List<dynamic> interests = documentSnapshot.get(listfield);
      return interests.cast<String>() ?? [];
    } else {
      throw Exception('User not found');
    }
  }


  Future<String?> getUserField(String uid, String fieldName) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.get(fieldName);
    } catch (e) {
      // Handle any errors that occur while fetching the document
      print('Error getting user field: $e');
      return null;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
      }, SetOptions(merge: true));

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  String? getCurrentUserUid() {
    return _firebaseAuth.currentUser?.uid;
  }
  String getCurrentUsersUid() {
    return _firebaseAuth.currentUser!.uid;
  }

  Future<UserCredential> createUserWithEmailAndPassword(
      String fio, String email, String password) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fio': fio,
        'players': [],
        'posts': [],
        'supports': [],
        'request':[],
        'photourl': "https://firebasestorage.googleapis.com/v0/b/players-clique.appspot.com/o/files%2Fnotfound.png?alt=media&token=abc8458f-cad7-4156-988e-332bf4439ac2",
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<void> signOut() async {
    return await FirebaseAuth.instance.signOut();
  }
}
