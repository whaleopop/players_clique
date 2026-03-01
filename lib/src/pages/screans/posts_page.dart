import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../components/posts/lenta_post.dart';

class Posts_Page extends StatefulWidget {
  @override
  _Posts_Page createState() => _Posts_Page();
}

class _Posts_Page extends State<Posts_Page> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const int _pageSize = 8;
  final List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadPosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collectionGroup('post')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    try {
      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _posts.addAll(snapshot.docs);
      }
      if (snapshot.docs.length < _pageSize) _hasMore = false;
      _error = null;
    } catch (e) {
      debugPrint('Posts load error: $e');
      _error = e.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    _posts.clear();
    _lastDoc = null;
    _hasMore = true;
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildStatsBar()),
              if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Ошибка загрузки постов:\n$_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_posts.isEmpty && !_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dynamic_feed_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Постов пока нет',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _posts.length) {
                          return _hasMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              : const SizedBox(height: 16);
                        }
                        final data =
                            _posts[index].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LentaPost(
                            imageUrl: data['imageUrl'] ?? '',
                            namePost: data['namePost'] ?? '',
                            descPost: data['descPost'] ?? '',
                            userId: data['userId'] ?? '',
                            onTap: () {},
                          ),
                        );
                      },
                      childCount: _posts.length + 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final total = snapshot.data?.docs.length ?? 0;
        final now = DateTime.now();
        final online = snapshot.data?.docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final ls = d['lastSeen'];
              if (ls == null) return false;
              return now.difference((ls as Timestamp).toDate()).inMinutes < 5;
            }).length ??
            0;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _chip(Icons.people_outline, '$total игроков',
                  const Color(0xFF0071BC)),
              const SizedBox(width: 16),
              _chip(Icons.circle, '$online онлайн', Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
