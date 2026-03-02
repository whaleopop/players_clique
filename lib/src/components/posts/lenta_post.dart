import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_service.dart';
import '../../../src/pages/screans/profile_sub_screen/profile_player.dart';
import 'comments_sheet.dart';

class LentaPost extends StatefulWidget {
  final String imageUrl;
  final String namePost;
  final String descPost;
  final String userId;   // post owner uid
  final String postId;   // document id in posts/{userId}/post/
  final void Function()? onTap;

  const LentaPost({
    Key? key,
    required this.imageUrl,
    required this.namePost,
    required this.descPost,
    required this.userId,
    required this.postId,
    this.onTap,
  }) : super(key: key);

  @override
  State<LentaPost> createState() => _LentaPostState();
}

class _LentaPostState extends State<LentaPost> {
  String? _fio;
  String? _photoUrl;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  DocumentReference get _postRef => FirebaseFirestore.instance
      .collection('posts')
      .doc(widget.userId)
      .collection('post')
      .doc(widget.postId);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final fio = await authService.getUserField(widget.userId, 'fio');
    final photo = await authService.getUserField(widget.userId, 'photourl');
    if (mounted) {
      setState(() {
        _fio = fio;
        _photoUrl = photo;
      });
    }
  }

  void _openProfile() {
    if (widget.userId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Profile_Player(uid: widget.userId)),
      );
    }
  }

  Future<void> _toggleLike(List<String> likedBy) async {
    final uid = _currentUid;
    if (uid == null) return;
    if (likedBy.contains(uid)) {
      await _postRef.update({'likedBy': FieldValue.arrayRemove([uid])});
    } else {
      await _postRef.update({'likedBy': FieldValue.arrayUnion([uid])});
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, ctrl) => CommentsSheet(
          postOwnerId: widget.userId,
          postId: widget.postId,
          scrollController: ctrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _postRef.snapshots(),
      builder: (context, postSnap) {
        final postData =
            postSnap.data?.data() as Map<String, dynamic>? ?? {};
        final likedBy =
            (postData['likedBy'] as List<dynamic>? ?? []).cast<String>();
        final isLiked = likedBy.contains(_currentUid);

        return StreamBuilder<QuerySnapshot>(
          stream: _postRef.collection('comments').snapshots(),
          builder: (context, commSnap) {
            final commentCount = commSnap.data?.docs.length ?? 0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: avatar + name
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openProfile,
                          child: ClipOval(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: _photoUrl != null &&
                                      _photoUrl!.isNotEmpty
                                  ? Image.network(
                                      _photoUrl!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      cacheWidth: 72,
                                      cacheHeight: 72,
                                      errorBuilder: (_, __, ___) =>
                                          _avatarFallback(),
                                    )
                                  : _avatarFallback(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openProfile,
                            child: Text(
                              _fio ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Square image
                  if (widget.imageUrl.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Image.network(
                        widget.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFF0071BC),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  // Actions: like + comment counts
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _toggleLike(likedBy),
                          icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey.shade600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '${likedBy.length}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _openComments,
                          icon: Icon(Icons.chat_bubble_outline,
                              color: Colors.grey.shade600),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '$commentCount',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  // Title + description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.namePost.isNotEmpty)
                          Text(
                            widget.namePost,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        if (widget.descPost.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.descPost,
                              style: const TextStyle(fontSize: 14)),
                        ],
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.lightBlue.shade100,
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}
