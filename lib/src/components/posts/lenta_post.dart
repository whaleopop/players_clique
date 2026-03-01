import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import '../../services/auth/auth_service.dart';
import '../../../src/pages/screans/profile_sub_screen/profile_player.dart';

class LentaPost extends StatefulWidget {
  final void Function()? onTap;
  final String imageUrl;
  final String namePost;
  final String descPost;
  final String userId;

  const LentaPost({
    Key? key,
    required this.imageUrl,
    required this.onTap,
    required this.namePost,
    required this.descPost,
    required this.userId,
  }) : super(key: key);

  @override
  State<LentaPost> createState() => _LentaPostState();
}

class _LentaPostState extends State<LentaPost> {
  String? _fio;
  String? _photoUrl;

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
        MaterialPageRoute(
          builder: (_) => Profile_Player(uid: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openProfile,
                    child: ClipOval(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: _photoUrl != null && _photoUrl!.isNotEmpty
                            ? Image.network(
                                _photoUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                cacheWidth: 72,
                                cacheHeight: 72,
                                errorBuilder: (_, __, ___) => _avatarFallback(),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Post image
            if (widget.imageUrl.isNotEmpty)
              Image.network(
                widget.imageUrl,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                cacheWidth: 800,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 280,
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
                  height: 280,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 48, color: Colors.grey),
                  ),
                ),
              ),
            // Actions + text
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(PlayerIcon.favorite,
                            color: Colors.lightBlue),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(PlayerIcon.chat_fill,
                            color: Colors.lightBlue),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (widget.namePost.isNotEmpty)
                    Text(
                      widget.namePost,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  if (widget.descPost.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(widget.descPost,
                        style: const TextStyle(fontSize: 14)),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.lightBlue.shade100,
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}
