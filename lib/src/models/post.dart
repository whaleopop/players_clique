import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String userId;
  final String namePost;
  final String descPost;
  final String imageUrl;
  final Timestamp timestamp;

  Post(
      {required this.userId,
        required this.namePost,
        required this.descPost,
        required this.imageUrl,
        required this.timestamp});
  Map<String, dynamic> toMap(){
    return{
      'userId':userId,
      'namePost':namePost,
      'descPost':descPost,
      'imageUrl':imageUrl,
      'timestamp':timestamp,
    };
  }
  factory Post.fromDocument(QueryDocumentSnapshot doc) {
    return Post(
      userId: doc['userId'],
      namePost: doc['namePost'],
      descPost: doc['descPost'],
      imageUrl: doc['imageUrl'],
      timestamp: doc['timestamp'],
    );
  }

}
