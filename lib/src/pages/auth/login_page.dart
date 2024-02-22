import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:players_clique/src/pages/auth/register_page.dart';
import 'package:players_clique/src/pages/start_page.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:provider/provider.dart';
import '../../adaptive_tools/form_factor.dart';
import '../../components/my_buttons.dart';
import '../../components/my_text_field.dart';
import '../../components/my_text_link.dart';

class MyLoginPage extends StatefulWidget {
  final void Function()? onTap;

  const MyLoginPage({super.key, required this.onTap});

  @override
  _MyLoginPage createState() => _MyLoginPage();
}

class _MyLoginPage extends State<MyLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void signIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signInWithEmailAndPassword(
          emailController.text, passwordController.text);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
          backgroundColor: Colors.white, // Устанавливаем белый фон для Scaffold
          body: Stack(children: [
            Center(
                child: SvgPicture.asset(
              "assets/vector/background_auth.svg",
              colorFilter: null,
                  fit: BoxFit.cover,
            )),
            Positioned(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(left: 30, right: 30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 45),
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
                        'Войти',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 36,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.w900,
                          height: 0,
                        ),
                      ),
                      SizedBox(height: 30),
                      MyTextField(
                          controller: emailController,
                          obscureText: false,
                          hintText: "Почта"),
                      SizedBox(height: 30),
                      MyTextField(
                          controller: passwordController,
                          obscureText: true,
                          hintText: "Пароль"),
                      SizedBox(height: 30),
                      Buttons(
                        onTap: () {
                          signIn();
                        },
                        text: "Войти",
                      ),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: const Text(
                          'Ёще нет аккаунта?',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w900,
                            height: 0,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ));
  }
}
