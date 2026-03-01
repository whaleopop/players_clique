import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../components/posts/lenta_post.dart';
import '../../models/post.dart';
import '../../services/auth/auth_service.dart';
import '../../services/cache/cache.dart';

class Posts_Page extends StatefulWidget {
  @override
  _Posts_Page createState() => _Posts_Page();
}

class _Posts_Page extends State<Posts_Page> {
  List<String> friendUids = [];
  late CacheService cacheService; // Declare a variable for CacheService

  @override
  void initState() {
    super.initState();
    cacheService = CacheService(); // Initialize CacheService
    _filterUsersUid();
  }

  void _filterUsersUid() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        List<dynamic> requestRefs = userDoc.get('players');
        List<String> requestUids = [];

        // Предполагается, что requestRefs - это список uid друзей (строки)
        for (var userId in requestRefs) {
          if (userId is String) {
            requestUids.add(userId);
            print(userId);
          } else {
            print("Unexpected type for user ID: $userId");
          }
        }

        if (mounted) {
          setState(() {
            friendUids = requestUids; // Обновление состояния здесь
          });
        }
      } catch (e) {
        print("Error fetching user documents: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: CupertinoNavigationBar(
          backgroundColor: Color(0xFF0071BC),
          middle: Text(
            'Лента',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchPosts(friendUids),
          builder: (BuildContext context,
              AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dynamic_feed_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Лента пуста', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Добавьте друзей, чтобы видеть их посты',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              );
            } else {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRequestListItem(snapshot.data![index]),
                ),
              );
            }
          },
        ),
      ),
    );
  }


  Future<List<DocumentSnapshot>> _fetchPosts(List<String> friendUids) async {
    List<DocumentSnapshot> allPosts = [];

    for (String uid in friendUids) {
      if (uid != null) {
        try {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('posts')
              .doc(uid)
              .collection("post")
              .get();

          for (var post in querySnapshot.docs) {
            DocumentSnapshot? cachedPost = cacheService.getFromCache(post.id);
            if (cachedPost != null) {
              allPosts.add(cachedPost);
            } else {
              allPosts.add(post);
              cacheService.addToCache(post.id, post);
            }
          }
        } catch (e) {
          print("Error fetching user posts: $e");
        }
      }
    }

    // Сортировка постов по timestamp

    allPosts.sort((a, b) => (b.data()! as Map<String, dynamic>)["timestamp"].compareTo((a.data()! as Map<String, dynamic>)["timestamp"]));


    return allPosts;
  }






  Widget _buildRequestListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
    return LentaPost(
      imageUrl: data["imageUrl"],
      namePost: data["namePost"],
      descPost: data["descPost"],
      userId: data["userId"],
      onTap: () {
        // Обработка нажатия на пост
      },
    );
  }
}
