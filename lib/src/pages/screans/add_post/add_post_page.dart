import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../../models/post.dart';
import '../../../services/post/post_service.dart';

class Add_Post_Page extends StatefulWidget {
  final PostService postService;

  const Add_Post_Page({Key? key, required this.postService}) : super(key: key);

  @override
  State<Add_Post_Page> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<Add_Post_Page> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String _mediaType = 'image'; // 'image' or 'video'

  // Image
  File? _selectedFile;
  Uint8List? _selectedFileBytes;

  // Video
  File? _selectedVideoFile;
  Uint8List? _selectedVideoBytes;
  String _selectedVideoName = '';

  bool _isLoading = false;

  bool get _hasMedia => _mediaType == 'image'
      ? (_selectedFileBytes != null || _selectedFile != null)
      : (_selectedVideoBytes != null || _selectedVideoFile != null);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    img.Image cropToSquare(img.Image image) {
      final size = min(image.width, image.height);
      final x = (image.width - size) ~/ 2;
      final y = (image.height - size) ~/ 2;
      return img.copyCrop(image, x, y, size, size);
    }

    setState(() {
      if (kIsWeb) {
        _selectedFileBytes = result.files.single.bytes;
        final image = img.decodeImage(_selectedFileBytes!);
        if (image != null) {
          _selectedFileBytes =
              Uint8List.fromList(img.encodeJpg(cropToSquare(image)));
        }
      } else {
        _selectedFile = File(result.files.single.path!);
        final image = img.decodeImage(_selectedFile!.readAsBytesSync());
        if (image != null) {
          _selectedFile!
              .writeAsBytesSync(img.encodeJpg(cropToSquare(image)));
        }
      }
    });
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null) return;
    setState(() {
      _selectedVideoName = result.files.single.name;
      if (kIsWeb) {
        _selectedVideoBytes = result.files.single.bytes;
      } else {
        _selectedVideoFile = File(result.files.single.path!);
      }
    });
  }

  Future<String> _uploadFile(dynamic data, String fileName) async {
    final ref = FirebaseStorage.instance.ref().child('posts/$fileName');
    UploadTask uploadTask;
    if (data is Uint8List) {
      uploadTask = ref.putData(data);
    } else if (data is File) {
      uploadTask = ref.putFile(data);
    } else {
      throw Exception('Unsupported data type');
    }
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _createPost() async {
    if (!_hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_mediaType == 'image'
                ? 'Выберите изображение'
                : 'Выберите видео')),
      );
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название поста')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String imageUrl = '';
      String? videoUrl;

      if (_mediaType == 'image') {
        final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await _uploadFile(
            kIsWeb ? _selectedFileBytes! : _selectedFile!, fileName);
      } else {
        final ext = _selectedVideoName.contains('.')
            ? _selectedVideoName.split('.').last
            : 'mp4';
        final fileName =
            'post_video_${DateTime.now().millisecondsSinceEpoch}.$ext';
        videoUrl = await _uploadFile(
            kIsWeb ? _selectedVideoBytes! : _selectedVideoFile!, fileName);
      }

      final post = Post(
        userId: FirebaseAuth.instance.currentUser!.uid,
        namePost: _nameCtrl.text.trim(),
        descPost: _descCtrl.text.trim(),
        imageUrl: imageUrl,
        timestamp: Timestamp.now(),
        videoUrl: videoUrl,
        mediaType: _mediaType,
      );
      await widget.postService.createPost(post);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пост опубликован!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0071BC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Новый пост',
          style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _createPost,
              child: const Text(
                'Опубликовать',
                style: TextStyle(
                    color: Color(0xFF0071BC), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media type toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeButton('image', Icons.image_outlined, 'Фото'),
                  _typeButton('video', Icons.videocam_outlined, 'Видео'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Media picker area
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : (_mediaType == 'image' ? _pickImage : _pickVideo),
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _hasMedia
                          ? Colors.transparent
                          : Colors.grey.shade300),
                  boxShadow: [
                    if (_hasMedia)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildMediaPreview(),
              ),
            ),
            const SizedBox(height: 16),
            // Name field
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Название',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Desc field
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Описание',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0071BC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Опубликовать',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String type, IconData icon, String label) {
    final isSelected = _mediaType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mediaType = type;
          // Clear previous selection when switching type
          _selectedFile = null;
          _selectedFileBytes = null;
          _selectedVideoFile = null;
          _selectedVideoBytes = null;
          _selectedVideoName = '';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF0071BC) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_mediaType == 'image') {
      if (!_hasMedia) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Нажмите чтобы выбрать фото',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        );
      }
      return Stack(fit: StackFit.expand, children: [
        kIsWeb
            ? Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
            : Image.file(_selectedFile!, fit: BoxFit.cover),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(6),
            child:
                const Icon(Icons.edit, color: Colors.white, size: 18),
          ),
        ),
      ]);
    } else {
      // Video
      if (!_hasMedia) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Нажмите чтобы выбрать видео',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_rounded,
              size: 56, color: Color(0xFF0071BC)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _selectedVideoName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text('Видео готово к публикации',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Выбрать другое'),
          ),
        ],
      );
    }
  }
}
