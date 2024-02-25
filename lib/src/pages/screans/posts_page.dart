import 'package:flutter/material.dart';



import '../../icons/player_icon_icons.dart';

class Post_Page extends StatefulWidget {
  @override
  _Post_Page createState() => _Post_Page();
}

class _Post_Page extends State<Post_Page> {
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
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 82,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x3F000000),
                              blurRadius: 4,
                              offset: Offset(0, 4),
                              spreadRadius: 0,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () {},
                              child: Icon(PlayerIcon.search),
                            ),
                            SizedBox(
                              width: 30,
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ],
              ))),
    );
  }
}
