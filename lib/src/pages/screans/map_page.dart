import 'package:flutter/material.dart';
import 'package:players_clique/src/icons/my_flutter_app_icons.dart';

import '../../components/messages/m_preview.dart';

class Map_Page extends StatefulWidget {
  @override
  _Map_Page createState() => _Map_Page();
}

class _Map_Page extends State<Map_Page> {
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
                            Text("Тут будет реализация карт"),
                            InkWell(
                              onTap: () {},
                              child: Icon(MyFlutterApp.search),
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
