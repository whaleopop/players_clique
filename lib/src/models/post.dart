import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String userId;
  final String namePost;
  final String descPost;
  final String imageUrl;
  final Timestamp timestamp;
  final String? videoUrl;
  final String mediaType; // 'image' or 'video'

  Post({
    required this.userId,
    required this.namePost,
    required this.descPost,
    required this.imageUrl,
    required this.timestamp,
    this.videoUrl,
    this.mediaType = 'image',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'namePost': namePost,
      'descPost': descPost,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'mediaType': mediaType,
      if (videoUrl != null) 'videoUrl': videoUrl,
    };
  }

  factory Post.fromDocument(QueryDocumentSnapshot doc) {
    return Post(
      userId: doc['userId'],
      namePost: doc['namePost'],
      descPost: doc['descPost'],
      imageUrl: doc['imageUrl'] as String? ?? '',
      timestamp: doc['timestamp'],
      videoUrl: doc['videoUrl'] as String?,
      mediaType: doc['mediaType'] as String? ?? 'image',
    );
  }
}
