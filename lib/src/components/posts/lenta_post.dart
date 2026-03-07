import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import 'video_player_section.dart';
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
        final mediaType = postData['mediaType'] as String? ?? 'image';
        final videoUrl = postData['videoUrl'] as String? ?? '';

        return StreamBuilder<QuerySnapshot>(
          stream: _postRef.collection('comments').snapshots(),
          builder: (context, commSnap) {
            final commentCount = commSnap.data?.docs.length ?? 0;

            final cs = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
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
                  // Media: track replace / video / image
                  if (mediaType == 'trackReplace')
                    _TrackReplaceCard(postData: postData)
                  else if (mediaType == 'video' && videoUrl.isNotEmpty)
                    VideoPlayerSection(videoUrl: videoUrl)
                  else if (widget.imageUrl.isNotEmpty)
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
                            color: cs.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFF366837),
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
                                ? PlayerIcon.favorite_fill
                                : PlayerIcon.favorite,
                            color: isLiked ? Colors.red : cs.onSurface.withValues(alpha: 0.5),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '${likedBy.length}',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _openComments,
                          icon: Icon(Icons.chat_bubble_outline,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '$commentCount',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
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

class _TrackReplaceCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  const _TrackReplaceCard({required this.postData});

  @override
  Widget build(BuildContext context) {
    final title = postData['trackTitle'] as String? ?? postData['namePost'] as String? ?? '';
    final artist = postData['trackArtist'] as String? ?? postData['descPost'] as String? ?? '';
    final coverUrl = postData['trackCoverUrl'] as String? ?? postData['imageUrl'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: coverUrl.isNotEmpty
                ? Image.network(coverUrl, width: 70, height: 70, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverPlaceholder())
                : _coverPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Лега" badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF5D4037)),
                      SizedBox(width: 3),
                      Text('Лега заменил трек', style: TextStyle(
                          color: Color(0xFF5D4037), fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.upload_rounded, color: Color(0xFF5D4037), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note_rounded, color: Color(0xFFFFC107), size: 30),
      );
}

