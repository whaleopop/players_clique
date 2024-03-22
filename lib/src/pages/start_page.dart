import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:players_clique/src/components/my_text_link.dart';
import 'package:players_clique/src/pages/auth/login_page.dart';
import 'package:players_clique/src/pages/auth/register_page.dart';
import '../components/my_buttons.dart';

class MySecondScreen extends StatefulWidget {
  @override
  _MySecondScreen createState() => _MySecondScreen();
}

class _MySecondScreen extends State<MySecondScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      backgroundColor: Colors.white, // Устанавливаем белый фон для Scaffold
      body: Stack(
        children: [
          Image.asset(
            "assets/image/sportman1.png",
            fit: BoxFit.cover, // Покрывает весь экран
            width: double.infinity, // Занимает всю ширину экрана
            height: double.infinity, // Занимает всю высоту экрана
          ),
          Positioned(
              top: 5,
              left: 35,
              right: 35,
              child: Align(
                child: SvgPicture.asset(
                  "assets/image/logo.svg",
                  height: 300,
                  width: 100,
                  colorFilter: null,
                ),
              )),
          Positioned(
              bottom: 70,
              left: 35,
              right: 35,
              child: Align(
                alignment: Alignment.bottomCenter,
              )),
        ],
      ),
    ));
  }
}
