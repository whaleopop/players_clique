import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/buttons/blue_buttons_icon.dart';
import 'package:provider/provider.dart';

import 'package:image/image.dart' as img;

import '../../../components/buttons/blue_buttons.dart';
import '../../../components/posts/image_post.dart';
import '../../../icons/player_icon_icons.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/cache/cache.dart';
import '../add_post/add_post_page.dart';


class Profile_Player extends StatefulWidget {

  final String uid;

  const Profile_Player({
    super.key,
    required this.uid,

  });
  @override
  _Profile_Player createState() => _Profile_Player();
}

class _Profile_Player extends State<Profile_Player> {
  PlatformFile? pickedFile;
  UploadTask? uploadTask;
  List<DocumentSnapshot> filteredUsersReUid =
  []; // State variable for filtered users
  final cacheService = CacheService();


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

  Future upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
    );
    if (result == null) return;
    setState(() {
      pickedFile = result.files.first;
    });

    // Обработка изображения
    File croppedFile = await cropImageToCircle(File(pickedFile!.path!));

    final path = 'files/${croppedFile.path}';
    final ref = FirebaseStorage.instance.ref().child(path);

    setState(() {
      uploadTask = ref.putFile(croppedFile);
    });
    final snapshot = await uploadTask!.whenComplete(() => {});
    final urlDownload = await snapshot.ref.getDownloadURL();
    print(urlDownload);
    setState(() {
      uploadTask = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    if (widget.uid != null) {
      authService.profileImageLoad(widget.uid, urlDownload);
    }
  }

  void signOut() {
    final authService = Provider.of<AuthService>(context, listen: false);

    authService.signOut();
  }

  Future<List<String>> loadUserFieldList(String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (widget.uid != null) {
      return await authService.getUserList(widget.uid, fieldName);
    } else {
      // Handle the case where there is no current user
      return [];
    }
  }

  Future<String?> loadUserField(String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (widget.uid != null) {
      return await authService.getUserField(widget.uid, fieldName);
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Распределение кнопок по ширине
                      children: [
                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(PlayerIcon.arrow_back_fill), // Используйте Icon из Material Icons, если PlayerIcon не доступен
                        ),
                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {},
                          icon: Icon(PlayerIcon.favorite), // Используйте Icon из Material Icons, если PlayerIcon не доступен
                        ),

                        IconButton(
                          color: Colors.lightBlue,
                          onPressed: () {},
                          icon: Icon(PlayerIcon.chat_fill), // Используйте Icon из Material Icons, если PlayerIcon не доступен
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
        appBar: CupertinoNavigationBar(),
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
    if (widget.uid != null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.uid)
            .collection("post")
            .get();
        return querySnapshot.docs;
      } catch (e) {
        print("Error fetching user posts: $e");
        return [];
      }
    } else {
      return [];
    }
  }
}
