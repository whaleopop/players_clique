import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:players_clique/src/components/my_text_field.dart';

import 'package:provider/provider.dart';

import '../../components/my_buttons.dart';
import '../../services/auth/auth_service.dart';

class MyRegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const MyRegisterPage({super.key, required this.onTap});

  @override
  _MyRegisterPage createState() => _MyRegisterPage();
}

class _MyRegisterPage extends State<MyRegisterPage> {
  final fioController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final repasswordController = TextEditingController();

  void signUp() async {
    if (passwordController.text != repasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Пароли не похожи"),
        ),
      );
      return;
    }
    if ("" == fioController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Введите своё имя"),
        ),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.createUserWithEmailAndPassword(
          fioController.text, emailController.text, passwordController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor:
        Colors.white, // Установка белого фона для всех Scaffold
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white, // Устанавливаем белый фон для Scaffold
        body: Stack(children: [
          Center(
              child: SvgPicture.asset(
                "assets/vector/background_auth.svg",
                colorFilter: null,
                fit: BoxFit.cover,
              )),
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: EdgeInsets.only(left: 30, right: 30),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 45),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 4,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Регистрация',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 15),
                  MyTextField(
                      controller: fioController,
                      obscureText: false,
                      hintText: "Имя"),
                  const SizedBox(height: 15),
                  MyTextField(
                      controller: emailController,
                      obscureText: false,
                      hintText: "Почта"),
                  SizedBox(height: 15),
                  MyTextField(
                      controller: passwordController,
                      obscureText: true,
                      hintText: "Пароль"),
                  SizedBox(height: 15),
                  MyTextField(
                      controller: repasswordController,
                      obscureText: true,
                      hintText: "Потвердите пароль"),
                  SizedBox(height: 15),
                  Buttons(
                    onTap: () {
                      signUp();
                    },
                    text: "Войти",
                  ),
                  SizedBox(height: 5),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: widget.onTap,
                        child: const Text(
                          'Есть аккаунт?',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
