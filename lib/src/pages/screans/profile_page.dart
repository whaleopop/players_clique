import 'dart:io';
import 'dart:math';

import '../../utils/web_update.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../components/buttons/blue_buttons.dart';
import '../../components/posts/image_post.dart';
import '../../icons/player_icon_icons.dart';
import 'package:image/image.dart' as img;
import '../../services/auth/auth_service.dart';
import '../../services/cache/cache.dart';
import '../../services/post/post_service.dart';
import '../../services/theme/theme_service.dart';
import 'add_post/add_post_page.dart';
import 'profile_sub_screen/profile_player.dart';
import '../../components/posts/comments_sheet.dart';
import '../../components/posts/video_player_section.dart';


class Profile_Page extends StatefulWidget {
  @override
  _Profile_Page createState() => _Profile_Page();
}

class _Profile_Page extends State<Profile_Page> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  PlatformFile? pickedFile;
  UploadTask? uploadTask;
  List<DocumentSnapshot> filteredUsersReUid =
      []; // State variable for filtered users
  final CacheService cacheService = CacheService();

  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _postsStream;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUid = authService.getCurrentUserUid();
    _userStream = _currentUid != null
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .snapshots()
        : const Stream.empty();
    _postsStream = _currentUid != null
        ? FirebaseFirestore.instance
            .collection('posts')
            .doc(_currentUid)
            .collection('post')
            .orderBy('timestamp', descending: true)
            .snapshots()
        : const Stream.empty();
  }

  Future<File> cropImageToCircle(File file) async {
    // Загрузка изображения
    img.Image? image = img.decodeImage(await file.readAsBytes());

    // Проверка, что изображение не null
    if (image == null) {
      throw Exception('Не удалось загрузить изображение');
    }

    // Обрезка изображения в круг
    img.Image croppedImage = img.copyCropCircle(image);

    // Сохранение обрезанного изображения в новый файл
    File newFile = File('${file.path}_cropped.jpg');
    await newFile.writeAsBytes(img.encodeJpg(croppedImage));

    return newFile;
  }

  File? _selectedFile; // This will be used to store the file for both Android and web
  Uint8List? _selectedFileBytes;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'doc'],
    );
    img.Image cropToSquare(img.Image image) {
      int size = min(image.width, image.height);
      int x = (image.width - size) ~/ 2;
      int y = (image.height - size) ~/ 2;
      return img.copyCrop(image, x, y, size, size);
    }
    img.Image resizeToSquare(img.Image image, {int size = 1080}) {
      int newWidth = size;
      int newHeight = size;
      img.Image resized = img.copyResize(image, width: newWidth, height: newHeight);
      return resized;
    }
    if (result != null) {
      setState(() {
        if (kIsWeb) {
          // On web, use the bytes property
          _selectedFileBytes = result.files.single.bytes;
          // Convert bytes to image
          img.Image? image = img.decodeImage(_selectedFileBytes!);
          // Crop or resize the image
          img.Image processedImage = img.copyCropCircle(image!); // or resizeToSquare(image)
          // Convert processed image back to bytes
          _selectedFileBytes = img.encodeJpg(processedImage) as Uint8List?;
        } else {
          // On Android, use the path property
          _selectedFile = File(result.files.single.path!);
          // Convert file to image
          img.Image? image = img.decodeImage(_selectedFile!.readAsBytesSync());
          // Crop or resize the image
          img.Image processedImage = img.copyCropCircle(image!); // or resizeToSquare(image)
          // Convert processed image back to file
          _selectedFile!.writeAsBytesSync(img.encodeJpg(processedImage));

        }
      });
      String? imageUrl;
      if (_selectedFileBytes != null) {
        // Generate a temporary file name
        String tempFileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        try {
          imageUrl = await _uploadFile(_selectedFileBytes!, tempFileName);
          final authService = Provider.of<AuthService>(context, listen: false);
          String? uid = authService.getCurrentUserUid();
          if (uid != null) {
            authService.profileImageLoad(uid, imageUrl);
          }
        } catch (e) {
          print("Error uploading file: $e");
          // Handle the error, e.g., show a dialog to the user
          return;
        }

      }

      if (_selectedFile != null) {
        // Generate a temporary file name for Android
        String tempFileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        try {
          imageUrl = await _uploadFile(_selectedFile!, tempFileName);
          final authService = Provider.of<AuthService>(context, listen: false);
          String? uid = authService.getCurrentUserUid();
          if (uid != null) {
            authService.profileImageLoad(uid, imageUrl);
          }
        } catch (e) {
          print("Error uploading file: $e");
          // Handle the error, e.g., show a dialog to the user
          return;
        }
      }

    }

  }

  Future<String> _uploadFile(dynamic data, String fileName) async {
    Reference ref = FirebaseStorage.instance.ref().child('posts/$fileName');
    UploadTask uploadTask;

    if (data is Uint8List) {
      uploadTask = ref.putData(data);
    } else if (data is File) {
      uploadTask = ref.putFile(data);
    } else {
      throw Exception('Unsupported data type for upload');
    }

    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  void signOut() {
    final authService = Provider.of<AuthService>(context, listen: false);

    authService.signOut();
  }

  Future<List<String>> loadUserFieldList(String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      return await authService.getUserList(uid, fieldName);
    } else {
      // Handle the case where there is no current user
      return [];
    }
  }

  Future<String?> loadUserField(String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      return await authService.getUserField(uid, fieldName);
    } else {
      // Handle the case where there is no current user
      return null;
    }
  }

  Widget _buildPostTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mediaType = data['mediaType'] as String? ?? 'image';
    final imageUrl = data['imageUrl'] as String? ?? '';

    if (mediaType == 'video') {
      return GestureDetector(
        onTap: () => _showPostDetail(doc),
        child: Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.play_circle_outline_rounded,
                color: Colors.white60, size: 40),
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showPostDetail(doc),
      child: ImagePost(imageUrl: imageUrl, onTap: () => _showPostDetail(doc)),
    );
  }

  void _showPostDetail(DocumentSnapshot doc) {
    if (_currentUid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (sheetCtx, ctrl) => _PostOwnerSheet(
          doc: doc,
          postOwnerId: _currentUid!,
          scrollController: ctrl,
          onEdit: () => _openEditDialog(doc),
          onDelete: () => _confirmDelete(doc),
        ),
      ),
    );
  }

  void _openEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['namePost'] ?? '');
    final descCtrl = TextEditingController(text: data['descPost'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Редактировать пост'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071BC)),
            onPressed: () async {
              Navigator.of(context).pop();
              if (_currentUid == null) return;
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(_currentUid)
                  .collection('post')
                  .doc(doc.id)
                  .update({
                'namePost': nameCtrl.text.trim(),
                'descPost': descCtrl.text.trim(),
              });
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить пост?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              if (_currentUid == null) return;
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(_currentUid)
                  .collection('post')
                  .doc(doc.id)
                  .delete();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: CustomScrollView(
          slivers: [
            // Профиль: аватар + инфо
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFFF5F7FA),
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                child: Column(
                  children: [
                    // Аватар
                    Stack(
                      children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: _userStream,
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                            final url = data['photourl'] as String? ?? '';
                            return CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.lightBlue.shade100,
                              backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
                              child: url.isEmpty
                                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                                  : null,
                            );
                          },
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _pickFile,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0071BC),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.add_a_photo, color: Colors.white, size: 15),
                            ),
                          ),
                        ),
                        if (kIsWeb)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Tooltip(
                              message: 'Обновить приложение',
                              child: GestureDetector(
                                onTap: reloadAndUpdate,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.system_update_alt,
                                      size: 16, color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Имя
                    StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                        final fio = data['fio'] as String? ?? '';
                        return Text(
                          fio,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 0.3,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    // Статистика
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: _postsStream,
                          builder: (context, snapshot) =>
                              _statItem('${snapshot.data?.docs.length ?? 0}', 'Посты'),
                        ),
                        Container(width: 1, height: 36, color: Colors.grey.shade300),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _userStream,
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                            final friends = (data['friends'] as List<dynamic>? ?? []).cast<String>();
                            return GestureDetector(
                              onTap: friends.isNotEmpty ? () => _openFriendsList(friends) : null,
                              child: _statItem('${friends.length}', 'Друзья'),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Кнопка Edit
                    BlueButton(onTap: _openEditProfile, text: 'Редактировать', width: double.infinity),
                    const SizedBox(height: 12),
                    // Иконки выход / тема / добавить пост
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _iconBtn(icon: PlayerIcon.logout_fill, onTap: signOut),
                        Consumer<ThemeService>(
                          builder: (context, themeService, _) => _iconBtn(
                            icon: themeService.isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            onTap: themeService.toggle,
                          ),
                        ),
                        _iconBtn(
                          icon: PlayerIcon.post_add,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Add_Post_Page(postService: PostService()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Разделитель
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Сетка постов
            StreamBuilder<QuerySnapshot>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Нет постов', style: TextStyle(color: Colors.grey))),
                    ),
                  );
                }
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPostTile(docs[index]),
                    childCount: docs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFriendsList(List<String> friendUids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Друзья', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: friendUids.length,
                itemBuilder: (context, i) => _FriendTile(uid: friendUids[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    if (_currentUid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
    if (!mounted) return;
    final fioCtrl = TextEditingController(text: doc.data()?['fio'] as String? ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Редактировать профиль'),
        content: TextField(
          controller: fioCtrl,
          decoration: const InputDecoration(labelText: 'Имя'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071BC)),
            onPressed: () async {
              Navigator.of(context).pop();
              if (_currentUid == null) return;
              final newFio = fioCtrl.text.trim();
              if (newFio.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUid)
                  .update({'fio': newFio});
              // stream auto-updates the name display
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF0071BC)),
      ),
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
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (mounted && doc.exists) {
      final d = doc.data()!;
      setState(() {
        _name = d['fio'] as String? ?? d['email'] as String?;
        _photo = d['photourl'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (_photo != null && _photo!.isNotEmpty)
            ? NetworkImage(_photo!) as ImageProvider
            : null,
        backgroundColor: Colors.lightBlue.shade100,
        child: (_photo == null || _photo!.isEmpty)
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(_name ?? '...'),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Profile_Player(uid: widget.uid)),
        );
      },
    );
  }
}

// ── Post detail sheet (owner view) ──────────────────────────────────────────

class _PostOwnerSheet extends StatelessWidget {
  final DocumentSnapshot doc;
  final String postOwnerId;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostOwnerSheet({
    required this.doc,
    required this.postOwnerId,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  DocumentReference get _postRef => FirebaseFirestore.instance
      .collection('posts')
      .doc(postOwnerId)
      .collection('post')
      .doc(doc.id);

  void _openComments(BuildContext context) {
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
          postOwnerId: postOwnerId,
          postId: doc.id,
          scrollController: ctrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialData = doc.data() as Map<String, dynamic>;
    return StreamBuilder<DocumentSnapshot>(
      stream: _postRef.snapshots(),
      builder: (context, postSnap) {
        final data =
            postSnap.data?.data() as Map<String, dynamic>? ?? initialData;
        final likedBy =
            (data['likedBy'] as List<dynamic>? ?? []).cast<String>();

        return StreamBuilder<QuerySnapshot>(
          stream: _postRef.collection('comments').snapshots(),
          builder: (context, commSnap) {
            final commentCount = commSnap.data?.docs.length ?? 0;

            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // Media: video or image
                  Builder(builder: (_) {
                    final mediaType =
                        data['mediaType'] as String? ?? 'image';
                    final videoUrl =
                        data['videoUrl'] as String? ?? '';
                    if (mediaType == 'video' && videoUrl.isNotEmpty) {
                      return VideoPlayerSection(videoUrl: videoUrl);
                    }
                    return AspectRatio(
                      aspectRatio: 1.0,
                      child: Image.network(
                        data['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Title + popup menu
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['namePost'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) {
                            Navigator.of(context).pop();
                            if (value == 'edit') onEdit();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Редактировать'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Удалить',
                                    style: TextStyle(color: Colors.red)),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Description
                  if ((data['descPost'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Text(data['descPost'],
                          style: const TextStyle(fontSize: 14)),
                    ),
                  // Who liked
                  if (likedBy.isNotEmpty) _LikedBySection(uids: likedBy),
                  const Divider(height: 1),
                  // Comments button
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF0071BC)),
                    title: Text(
                      'Комментарии ($commentCount)',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openComments(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Who liked section ────────────────────────────────────────────────────────

class _LikedBySection extends StatefulWidget {
  final List<String> uids;
  const _LikedBySection({required this.uids});

  @override
  State<_LikedBySection> createState() => _LikedBySectionState();
}

class _LikedBySectionState extends State<_LikedBySection> {
  List<String> _names = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_LikedBySection old) {
    super.didUpdateWidget(old);
    if (old.uids != widget.uids) _load();
  }

  Future<void> _load() async {
    final names = <String>[];
    for (final uid in widget.uids) {
      final d = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (d.exists) {
        names.add(d.data()?['fio'] as String? ?? 'Пользователь');
      }
    }
    if (mounted) setState(() { _names = names; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: LinearProgressIndicator(),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            const TextSpan(text: '❤️  '),
            const TextSpan(
              text: 'Нравится: ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: _names.join(', ')),
          ],
        ),
      ),
    );
  }
}

