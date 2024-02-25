import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FireStorageService extends ChangeNotifier {
  FireStorageService();

  static Future<dynamic> loadFromStorage(BuildContext context, String image) async {
    return await FirebaseStorage.instance.ref().child(image).getDownloadURL();
  }

  Future<void> uploadImage(File imageFile, String path) async {
    try {
      await FirebaseStorage.instance.ref(path).putFile(imageFile);
    } on FirebaseException catch (e) {
      // Handle errors
    }
  }
  Future<void> saveImageUrlToFirestore(String url, String documentId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(documentId).set({
        'photourl': url,
      });
    } on FirebaseException catch (e) {
      // Handle errors
    }
  }


}
