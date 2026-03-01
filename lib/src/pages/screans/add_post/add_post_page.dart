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

  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
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
          _selectedFileBytes = Uint8List.fromList(
              img.encodeJpg(cropToSquare(image)));
        }
      } else {
        _selectedFile = File(result.files.single.path!);
        final image = img.decodeImage(_selectedFile!.readAsBytesSync());
        if (image != null) {
          _selectedFile!.writeAsBytesSync(img.encodeJpg(cropToSquare(image)));
        }
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
    if (_selectedFileBytes == null && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите изображение')),
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
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await _uploadFile(
        kIsWeb ? _selectedFileBytes! : _selectedFile!,
        fileName,
      );

      final post = Post(
        userId: FirebaseAuth.instance.currentUser!.uid,
        namePost: _nameCtrl.text.trim(),
        descPost: _descCtrl.text.trim(),
        imageUrl: imageUrl,
        timestamp: Timestamp.now(),
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
    final hasImage = _selectedFileBytes != null || _selectedFile != null;

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
            // Image picker
            GestureDetector(
              onTap: _isLoading ? null : _pickFile,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: hasImage
                          ? Colors.transparent
                          : Colors.grey.shade300),
                  boxShadow: [
                    if (hasImage)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Stack(fit: StackFit.expand, children: [
                        kIsWeb
                            ? Image.memory(_selectedFileBytes!,
                                fit: BoxFit.cover)
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
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ])
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Нажмите чтобы выбрать фото',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
