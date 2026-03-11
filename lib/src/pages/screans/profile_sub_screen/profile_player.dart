import 'package:cached_network_image/cached_network_image.dart';
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

class _ProfilePlayerState extends State<Profile_Player>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<QuerySnapshot> _postsStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.uid)
        .collection('post')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _openFriendsList(List<String> friends) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FriendsSheet(friendIds: friends),
    );
  }

  void _openChat(String fio) {
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
    super.build(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnap) {
        final userData =
            (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final fio = userData['fio'] as String? ?? '';
        final photo = userData['photourl'] as String? ?? '';
        final banner = userData['bannerUrl'] as String? ?? '';
        final friends = List<String>.from(userData['friends'] ?? []);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: CustomScrollView(
              slivers: [
                // ── App bar with banner ──────────────────────────────
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF366837)),
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
                  flexibleSpace: FlexibleSpaceBar(
                    background: banner.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: banner,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: const Color(0xFF366837)),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF366837), Color(0xFF1C4A1E)],
                              ),
                            ),
                          ),
                  ),
                ),

                // ── Profile header card ──────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFCCE5CC),
                          backgroundImage: photo.isNotEmpty
                              ? CachedNetworkImageProvider(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person,
                                  size: 48, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fio,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Stats row
                        StreamBuilder<QuerySnapshot>(
                          stream: _postsStream,
                          builder: (context, postsSnap) {
                            final posts = postsSnap.data?.docs ?? [];
                            final regularPosts = posts
                                .where((d) =>
                                    (d.data()
                                        as Map<String,
                                            dynamic>)['mediaType'] !=
                                    'trackReplace')
                                .length;
                            final musicPosts = posts
                                .where((d) =>
                                    (d.data()
                                        as Map<String,
                                            dynamic>)['mediaType'] ==
                                    'trackReplace')
                                .length;
                            return Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                _statItem(
                                    regularPosts.toString(), 'Посты',
                                    null),
                                const SizedBox(width: 32),
                                _statItem(
                                    musicPosts.toString(), 'Треки',
                                    null),
                                const SizedBox(width: 32),
                                _statItem(
                                  friends.length.toString(),
                                  'Друзья',
                                  friends.isNotEmpty
                                      ? () => _openFriendsList(friends)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        // Message button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openChat(fio),
                            icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18),
                            label: const Text('Написать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF366837),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Sticky tab bar ───────────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      labelColor:
                          const Color(0xFF366837),
                      unselectedLabelColor:
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                      indicatorColor: const Color(0xFF366837),
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                        Tab(
                            icon: Icon(
                                Icons.music_note_rounded,
                                size: 20)),
                      ],
                    ),
                  ),
                ),

                // ── Tab content ──────────────────────────────────────
                SliverFillRemaining(
                  child: TabBarView(
                    children: [
                      _PostsTab(
                          postsStream: _postsStream,
                          onTap: _showPostDialog),
                      _MusicTab(postsStream: _postsStream),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(
      String value, String label, VoidCallback? onTap) {
    final content = Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: data['imageUrl'] ?? '',
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const SizedBox(height: 180),
              ),
            ),
            if ((data['namePost'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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

// ── Tab: Posts grid ────────────────────────────────────────────────────────

class _PostsTab extends StatefulWidget {
  final Stream<QuerySnapshot> postsStream;
  final void Function(Map<String, dynamic>) onTap;

  const _PostsTab({required this.postsStream, required this.onTap});

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: widget.postsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snap.data!.docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['mediaType'] !=
                'trackReplace')
            .toList();

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 52,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 10),
                Text('Постов пока нет',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data =
                posts[index].data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] as String? ?? '';
            if (imageUrl.isEmpty) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => widget.onTap(data),
              child: ImagePost(
                imageUrl: imageUrl,
                onTap: () => widget.onTap(data),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab: Music (trackReplace) ──────────────────────────────────────────────

class _MusicTab extends StatefulWidget {
  final Stream<QuerySnapshot> postsStream;

  const _MusicTab({required this.postsStream});

  @override
  State<_MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<_MusicTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: widget.postsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tracks = snap.data!.docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['mediaType'] ==
                'trackReplace')
            .toList();

        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off_rounded,
                    size: 52,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 10),
                Text('Треков пока нет',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final data =
                tracks[i].data() as Map<String, dynamic>;
            final title =
                data['trackTitle'] as String? ?? data['namePost'] ?? '';
            final artist = data['trackArtist'] as String? ??
                data['descPost'] ?? '';
            final coverUrl = data['trackCoverUrl'] as String? ??
                data['imageUrl'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1C2C1E),
                          const Color(0xFF162218),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF1F6F1),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _coverPlaceholder(),
                                )
                              : _coverPlaceholder(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.upload_file_rounded,
                            color: Color(0xFF366837), size: 20),
                      ],
                    ),
                  ),
                  // Swag image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    child: Image.asset(
                      'assets/image/swag.jpg',
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
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

  Widget _coverPlaceholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF366837).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note_rounded,
            color: Color(0xFF366837), size: 24),
      );
}

// ── Tab bar delegate ───────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Friends bottom sheet ───────────────────────────────────────────────────

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
          backgroundColor: const Color(0xFFCCE5CC),
          backgroundImage: photo.isNotEmpty
              ? CachedNetworkImageProvider(photo)
              : null,
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
