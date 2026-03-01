import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
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
import 'add_post/add_post_page.dart';


class Profile_Page extends StatefulWidget {
  @override
  _Profile_Page createState() => _Profile_Page();
}

class _Profile_Page extends State<Profile_Page> {
  PlatformFile? pickedFile;
  UploadTask? uploadTask;
  List<DocumentSnapshot> filteredUsersReUid =
      []; // State variable for filtered users
  final CacheService cacheService = CacheService();

  late Future<String?> _fioFuture;
  late Future<String?> _photoFuture;
  late Future<List<String>> _playersFuture;
  late Future<List<DocumentSnapshot>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _fioFuture = loadUserField("fio");
    _photoFuture = loadUserField("photourl");
    _playersFuture = loadUserFieldList("players");
    _postsFuture = _fetchPosts();
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

  Widget _buildRequestListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
    print(data);
    // Проверяем, содержит ли документ адрес электронной почты
    if (data['imageUrl'] != "") {
      print(data['imageUrl']);
      // Создаем виджет ListTile с изображением и информацией о пользователе
      return ImagePost(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(data['namePost']),
                    ),
                    PopupMenuButton<String>(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.lightBlue, // Пример цвета
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                                Text(
                                  "Удалить",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            )),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: Colors.white,
                              ),
                              Text(
                                "Удалить",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (String value) {
                        // Обработка выбора пользователя
                      },
                    )
                  ],
                ),
                content: SingleChildScrollView(
                    child: ListBody(children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    // чтобы содержимое не занимало слишком много места
                    children: <Widget>[
                      Image.network(
                        data['imageUrl'],
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Добавляем небольшой отступ
                      Text(data['descPost']),
                      // Здесь ваш длинный текст
                    ],
                  ),
                ])),
                actions: <Widget>[
                  Container(
                    width: double.infinity, // Занимает всю доступную ширину
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      // Распределение кнопок по ширине
                      children: [
                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(PlayerIcon
                              .arrow_back_fill), // Используйте Icon из Material Icons, если PlayerIcon не доступен
                        ),
                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {},
                          icon: Icon(PlayerIcon
                              .favorite), // Используйте Icon из Material Icons, если PlayerIcon не доступен
                        ),
                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {},
                          icon: Icon(PlayerIcon
                              .chat_fill), // Используйте Icon из Material Icons, если PlayerIcon не доступен
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
        imageUrl: data['imageUrl'],
      );
    } else {
      // Если адрес электронной почты отсутствует, возвращаем пустой Container
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: CustomScrollView(
          slivers: [
            // Шапка профиля
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Синий баннер
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0071BC), Color(0xFF29ABE2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Белая карточка профиля
                  Padding(
                    padding: const EdgeInsets.only(top: 90),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FA),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: Column(
                        children: [
                          // Имя
                          FutureBuilder(
                            future: _fioFuture,
                            builder: (context, AsyncSnapshot<String?> snapshot) {
                              final name = snapshot.data ?? '';
                              return Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Статистика
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statItem('0', 'Посты'),
                              Container(width: 1, height: 36, color: Colors.grey.shade300),
                              FutureBuilder(
                                future: _playersFuture,
                                builder: (context, AsyncSnapshot<List<String>> snapshot) {
                                  final count = snapshot.data?.length ?? 0;
                                  return _statItem('$count', 'Игроки');
                                },
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300),
                              _statItem('0', 'Саппорты'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Кнопки Edit / Share
                          Row(
                            children: [
                              Expanded(
                                child: BlueButton(onTap: () {}, text: 'Редактировать', width: double.infinity),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BlueButton(onTap: () {}, text: 'Поделиться', width: double.infinity),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Иконки выход / добавить пост
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _iconBtn(icon: PlayerIcon.logout_fill, onTap: signOut),
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
                  // Аватар
                  Positioned(
                    top: 88,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          ClipOval(
                            child: SizedBox.fromSize(
                              size: const Size.fromRadius(50),
                              child: FutureBuilder(
                                future: _photoFuture,
                                builder: (context, AsyncSnapshot<String?> snapshot) {
                                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    return Image.network(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.lightBlue.shade100,
                                        child: const Icon(Icons.person, size: 50, color: Colors.white),
                                      ),
                                    );
                                  }
                                  return Container(
                                    color: Colors.lightBlue.shade100,
                                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickFile,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0071BC),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.add_a_photo, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Разделитель
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Сетка постов
            FutureBuilder<List<DocumentSnapshot>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Нет постов', style: TextStyle(color: Colors.grey))),
                    ),
                  );
                }
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRequestListItem(snapshot.data![index]),
                    childCount: snapshot.data!.length,
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

  Future<List<DocumentSnapshot>> _fetchPosts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      // Проверяем, кэшированы ли уже документы
      if (cacheService.isCached(uid)) {
        // Если кэшированы, возвращаем их
        return [cacheService.getFromCache(uid)!];
      } else {
        try {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('posts')
              .doc(uid)
              .collection("post")
              .get();
          // Добавляем документы в кэш
          for (final doc in querySnapshot.docs) {
            cacheService.addToCache(doc.id, doc);
          }
          return querySnapshot.docs;
        } catch (e) {
          return [];
        }
      }
    } else {
      return [];
    }
  }
}
