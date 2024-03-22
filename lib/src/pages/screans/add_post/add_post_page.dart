import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img; // Import the image package

import '../../../models/post.dart';
import '../../../services/post/post_service.dart';

class Add_Post_Page extends StatefulWidget {
  final PostService postService;

  Add_Post_Page({Key? key, required this.postService}) : super(key: key);

  @override
  _Add_Post_Page createState() => _Add_Post_Page();
}

class _Add_Post_Page extends State<Add_Post_Page> {
  final TextEditingController _postContentController = TextEditingController();
  final TextEditingController _postDescriptionController = TextEditingController();
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
          img.Image processedImage = cropToSquare(image!); // or resizeToSquare(image)
          // Convert processed image back to bytes
          _selectedFileBytes = img.encodeJpg(processedImage) as Uint8List?;
        } else {
          // On Android, use the path property
          _selectedFile = File(result.files.single.path!);
          // Convert file to image
          img.Image? image = img.decodeImage(_selectedFile!.readAsBytesSync());
          // Crop or resize the image
          img.Image processedImage = cropToSquare(image!); // or resizeToSquare(image)
          // Convert processed image back to file
          _selectedFile!.writeAsBytesSync(img.encodeJpg(processedImage));
        }
      });
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


  Future<void> _createPost() async {
    String content = _postContentController.text;
    String description = _postDescriptionController.text;
    String? imageUrl;

    if (_selectedFileBytes != null) {
      // Generate a temporary file name
      String tempFileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      try {
        imageUrl = await _uploadFile(_selectedFileBytes!, tempFileName);
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
      } catch (e) {
        print("Error uploading file: $e");
        // Handle the error, e.g., show a dialog to the user
        return;
      }
    }

    try {
      if (imageUrl != null) {
        Post post = Post(
          userId: FirebaseAuth.instance.currentUser!.uid,
          namePost: content,
          descPost: description,
          imageUrl: imageUrl,
          timestamp: Timestamp.now(),
        );
        await widget.postService.createPost(post);
      } else {
        // Handle the case where no image URL is available
        // For example, show an error message or prompt the user to select an image
      }
      // Optionally, clear the form or show a success message
    } catch (e) {
      print("Error creating post: $e");
      // Handle the error, e.g., show a dialog to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text('Создание нового поста'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: _selectedFileBytes == null && _selectedFile == null
                        ? Icon(Icons.image, size: 100)
                        : kIsWeb
                        ? Image.memory(
                      _selectedFileBytes!,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
                      _selectedFile!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton(
                      onPressed: _pickFile,
                      tooltip: 'Pick File',
                      child: Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: _postContentController,
                decoration: InputDecoration(
                  hintText: 'Введите текст поста',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _postDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Введите описание поста',
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createPost,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Создать пост',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
