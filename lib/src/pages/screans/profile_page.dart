import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/buttons/blue_buttons.dart';
import '../../icons/player_icon_icons.dart';
import '../../services/auth/auth_service.dart';
import 'profile_sub_screen/add_friend.dart';

class Profile_Page extends StatefulWidget {
  @override
  _Profile_Page createState() => _Profile_Page();
}

class _Profile_Page extends State<Profile_Page> {
  PlatformFile? pickedFile;
  UploadTask? uploadTask;

  Future upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
    );
    if (result == null) return;
    setState(() {
      pickedFile = result.files.first;
    });

    final path = 'files/${pickedFile!.name}';
    final file = File(pickedFile!.path!);

    final ref = FirebaseStorage.instance.ref().child(path);

    setState(() {
      uploadTask = ref.putFile(file);
    });
    final snapshot = await uploadTask!.whenComplete(() => {});
    final urlDownload = await snapshot.ref.getDownloadURL();
    print(urlDownload);
    setState(() {
      uploadTask = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      authService.profileImageLoad(uid, urlDownload);
    }
  }

  void signOut() {
    final authService = Provider.of<AuthService>(context, listen: false);

    authService.signOut();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      theme: ThemeData(
        scaffoldBackgroundColor:
            Colors.white, // Установка белого фона для всех Scaffold
      ),
      home: SafeArea(
        child: Scaffold(
          body: Container(
            child: Stack(
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
                Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: 160,
                      decoration: const BoxDecoration(
                        color: Color(0x660071BC),
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
                                  color: Color(0xFF0071BC),
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
                                  color: Color(0xFF0071BC),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 1,
                                        spreadRadius: 10),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: upload, //getImage,
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
                              Text("Posts",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  "0",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text("Players",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text("0",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text("Supports",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        BlueButtons(
                          onTap: () {},
                          text: 'Edit profile',
                        ),
                        BlueButtons(
                          onTap: () {},
                          text: 'Share profile',
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 30,
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
                            return Text(
                                "${snapshot.data}"); // Display the field value if it's available
                          } else {
                            return Text(
                                "No data"); // Show a message if there's no data
                          }
                        }),

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
                                PlayerIcon.add_vector,
                                size: 25,
                                color: Color(0xFF0071BC),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Add_Friends_Page()),
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
                                PlayerIcon.add_post,
                                size: 25,
                                color: Color(0xFF0071BC),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => Add_Friends_Page()),
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
                              child: Icon(
                                PlayerIcon.add_friends,
                                size: 23,
                                color: Color(0xFF0071BC),
                              ),
                            ),
                          ),
                        ])
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
