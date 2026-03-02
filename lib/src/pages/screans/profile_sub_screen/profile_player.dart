import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/pages/screans/chat/chat_page.dart';

import '../../../components/posts/image_post.dart';

class Profile_Player extends StatefulWidget {
  final String uid;

  const Profile_Player({super.key, required this.uid});

  @override
  State<Profile_Player> createState() => _ProfilePlayerState();
}

class _ProfilePlayerState extends State<Profile_Player> {
  Map<String, dynamic> _userData = {};
  List<DocumentSnapshot> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    final postsSnap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.uid)
        .collection('post')
        .orderBy('timestamp', descending: true)
        .get();
    if (mounted) {
      setState(() {
        _userData = userDoc.data() ?? {};
        _posts = postsSnap.docs;
        _loading = false;
      });
    }
  }

  void _openFriendsList() {
    final friends = List<String>.from(_userData['friends'] ?? []);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FriendsSheet(friendIds: friends),
    );
  }

  void _openChat() {
    final fio = _userData['fio'] as String? ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          receiveruserEmail: fio,
          receiverUserID: widget.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final fio = _userData['fio'] as String? ?? '';
    final photo = _userData['photourl'] as String? ?? '';
    final friends = List<String>.from(_userData['friends'] ?? []);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0071BC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          fio,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Header card ---
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.lightBlue.shade100,
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo)
                        : null,
                    child: photo.isEmpty
                        ? const Icon(Icons.person,
                            size: 52, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fio,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statItem(_posts.length.toString(), 'Посты', null),
                      const SizedBox(width: 40),
                      _statItem(
                        friends.length.toString(),
                        'Друзья',
                        friends.isNotEmpty ? _openFriendsList : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Message button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Написать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0071BC),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // --- Posts grid ---
            if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'Постов пока нет',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 15),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(2),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final data =
                      _posts[index].data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String? ?? '';
                  if (imageUrl.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => _showPostDialog(data),
                    child: ImagePost(
                      imageUrl: imageUrl,
                      onTap: () => _showPostDialog(data),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, VoidCallback? onTap) {
    final content = Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  void _showPostDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                data['imageUrl'] ?? '',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if ((data['namePost'] as String? ?? '').isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  data['namePost'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            if ((data['descPost'] as String? ?? '').isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(data['descPost'],
                    style: const TextStyle(fontSize: 14)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Friends bottom sheet ---
class _FriendsSheet extends StatelessWidget {
  final List<String> friendIds;

  const _FriendsSheet({required this.friendIds});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Друзья',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const Divider(height: 16),
        Expanded(
          child: friendIds.isEmpty
              ? Center(
                  child: Text(
                    'Нет друзей',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )
              : ListView.builder(
                  itemCount: friendIds.length,
                  itemBuilder: (context, i) =>
                      _FriendTile(uid: friendIds[i]),
                ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatefulWidget {
  final String uid;

  const _FriendTile({required this.uid});

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get()
        .then((doc) {
      if (mounted) setState(() => _data = doc.data());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('...'),
      );
    }
    final fio = _data!['fio'] as String? ?? '';
    final photo = _data!['photourl'] as String? ?? '';

    return ListTile(
      leading: GestureDetector(
        onTap: () => _openProfile(context),
        child: CircleAvatar(
          backgroundColor: Colors.lightBlue.shade100,
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
      ),
      title: Text(fio,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => _openProfile(context),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Profile_Player(uid: widget.uid),
      ),
    );
  }
}
