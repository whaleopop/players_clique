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
                      Image.network(data['imageUrl']),
                      // Замените URL_КАРТИНКИ на URL вашей картинки
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
        body: SingleChildScrollView(
          child: Container(
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: 414,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3F000000),
                            blurRadius: 4,
                            offset: Offset(0, 4),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                    ),
                    FutureBuilder<List<DocumentSnapshot>>(
                      future: _fetchPosts(),
                      builder: (BuildContext context,
                          AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator(); // Отображение индикатора загрузки
                        } else if (snapshot.hasError) {
                          return Text(
                              'Error: ${snapshot.error}'); // Отображение ошибки
                        } else {
                          return Container(
                            height: 400,
                            child: GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                              ),
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) =>
                                  _buildRequestListItem(snapshot.data![index]),
                            ),
                          );
                        }
                      },
                    )
                  ],

                  //GRID VIEW POSTS FUTURE BUILDER
                ),
                Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: 160,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0071BC),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3F000000),
                            blurRadius: 4,
                            offset: Offset(0, 4),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    SizedBox(
                      height: 40,
                    ),
                    Stack(
                      children: [
                        Center(
                          child: ClipOval(
                            child: SizedBox.fromSize(
                              size: Size.fromRadius(83), // Image radius
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.lightBlue,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Center(
                            child: ClipOval(
                          child: SizedBox.fromSize(
                            size: Size.fromRadius(83), // Image radius
                            child: FutureBuilder(
                                future: loadUserField("photourl"),
                                builder: (BuildContext context,
                                    AsyncSnapshot<String?> snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator(); // Show a loading indicator while waiting for the data
                                  } else if (snapshot.hasError) {
                                    return Text(
                                        "${snapshot.error}"); // Show an error message if there's an error
                                  } else if (snapshot.hasData) {
                                    return Image.network(
                                      "${snapshot.data}",
                                      fit: BoxFit.cover,
                                    ); // Display the field value if it's available
                                  } else {
                                    return Text(
                                        "No data"); // Show a message if there's no data
                                  }
                                }),
                          ),
                        )),
                        Positioned(
                          right: 80,
                          child: ClipOval(
                            child: SizedBox.fromSize(
                              size: Size.fromRadius(20), // Image radius
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.lightBlue,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 1,
                                        spreadRadius: 10),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: _pickFile, //getImage,
                                  child: Icon(
                                    Icons.add_a_photo,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 16,
                              ),
                              Text("0",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("Посты",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FutureBuilder(
                                    future: loadUserFieldList("players"),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<List<String>> snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const CircularProgressIndicator(); // Show a loading indicator while waiting for the data
                                      } else if (snapshot.hasError) {
                                        return Text(
                                            "${snapshot.error}"); // Show an error message if there's an error
                                      } else if (snapshot.hasData) {
                                        return Text("${snapshot.data?.length}",
                                            style: TextStyle(
                                                fontWeight: FontWeight
                                                    .bold)); // Display the field value if it's available
                                      } else {
                                        return Text(
                                            "No data"); // Show a message if there's no data
                                      }
                                    }),
                                Text("Игроки",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(width: 100),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("0",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text("Саппорты",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    FutureBuilder(
                        future: loadUserField("fio"),
                        builder: (BuildContext context,
                            AsyncSnapshot<String?> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator(); // Show a loading indicator while waiting for the data
                          } else if (snapshot.hasError) {
                            return Text(
                                "${snapshot.error}"); // Show an error message if there's an error
                          } else if (snapshot.hasData) {
                            return Text("${snapshot.data}",
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold, // Делает текст жирным
                                  fontSize: 18,
                                  letterSpacing: 2.0,
                                )); // Display the field value if it's available
                          } else {
                            return Text(
                                "No data"); // Show a message if there's no data
                          }
                        }),
                    SizedBox(
                      height: 16,
                    ),
                    Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        BlueButton(
                          onTap: () {},
                          text: 'Edit profile',
                          width: 150,
                        ),
                        BlueButton(
                            onTap: () {}, text: 'Share profile', width: 150),
                      ],
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Row(
                        textDirection: TextDirection.ltr,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: signOut,
                            child: Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3F000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 4),
                                    spreadRadius: 0,
                                  )
                                ],
                              ),
                              child: Icon(
                                PlayerIcon.logout_fill,
                                size: 25,
                                color: Colors.lightBlue,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Add_Post_Page(
                                        postService: PostService())),
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3F000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 4),
                                    spreadRadius: 0,
                                  )
                                ],
                              ),
                              child: const Icon(
                                PlayerIcon.post_add,
                                size: 25,
                                color: Colors.lightBlue,
                              ),
                            ),
                          ),
                        ]),
                  ],
                ),
              ],
            ),
          ),
        ),
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
          querySnapshot.docs.forEach((doc) {
            cacheService.addToCache(doc.id, doc);
          });
          return querySnapshot.docs;
        } catch (e) {
          print("Error fetching user posts: $e");
          return [];
        }
      }
    } else {
      return [];
    }
  }
}
