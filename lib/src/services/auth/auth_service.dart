import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  profileLoad(String uid, String fio) async {
    try {
    _firestore.collection('users').doc(uid).set({
      'fio': fio
    }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
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
        'players': 0,
        'posts': 0,
        'supports': 0,
        'photourl': ""
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
