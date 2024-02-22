import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth/auth_service.dart';

class Profile_Page extends StatefulWidget {
  @override
  _Profile_Page createState() => _Profile_Page();
}

class _Profile_Page extends State<Profile_Page> {
  void signOut() {
    final authService = Provider.of<AuthService>(context, listen: false);

    authService.signOut();
  }

  profile_upload() {}

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
      home: Scaffold(
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
                    height: 157,
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
                    height: 75,
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
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 5,
                                    blurRadius: 7,
                                    offset: Offset(
                                        4, 4), // changes position of shadow
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
                            child: Image.asset("assets/image/sportman1.png",
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 36.90,
                        child: const Stack(
                          children: [
                            Positioned(
                              left: 23,
                              top: 0,
                              child: Text(
                                '0',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Arimo',
                                  fontWeight: FontWeight.w700,
                                  height: 0,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 19.90,
                              child: Text(
                                'Players',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Arimo',
                                  fontWeight: FontWeight.w700,
                                  height: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 50,
                      ),
                      Column(
                        children: [
                          const SizedBox(
                            height: 32,
                          ),
                          Container(
                            width: 54,
                            height: 36.90,
                            child: const Stack(
                              children: [
                                Positioned(
                                  left: 23,
                                  top: 0,
                                  child: Text(
                                    '0',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontFamily: 'Arimo',
                                      fontWeight: FontWeight.w700,
                                      height: 0,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 19.90,
                                  child: Text(
                                    'Players',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontFamily: 'Arimo',
                                      fontWeight: FontWeight.w700,
                                      height: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        width: 50,
                      ),
                      Container(
                        width: 54,
                        height: 36.90,
                        child: const Stack(
                          children: [
                            Positioned(
                              left: 23,
                              top: 0,
                              child: Text(
                                '0',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Arimo',
                                  fontWeight: FontWeight.w700,
                                  height: 0,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 19.90,
                              child: Text(
                                'Players',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Arimo',
                                  fontWeight: FontWeight.w700,
                                  height: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  FutureBuilder(
                      future: loadUserField("fio"),
                      builder: (BuildContext context,
                          AsyncSnapshot<String?> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator(); // Show a loading indicator while waiting for the data
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
                  IconButton(onPressed: signOut, icon: Icon(Icons.logout)),

                  Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children:[
                    Container(
                      width: 100,
                      height: 40,
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
                    Container(
                      width: 100,
                      height: 40,
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
                    Container(
                      width: 100,
                      height: 40,
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
                  ])
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget displayUserInformation(context, snapshot) {
    final fio = snapshot.data;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "${fio}",
            style: TextStyle(fontSize: 10),
          ),
        )
      ],
    );
  }
}
