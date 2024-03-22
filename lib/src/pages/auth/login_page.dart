import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:provider/provider.dart';
import '../../components/my_buttons.dart';
import '../../components/my_text_field.dart';

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
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white, // Устанавливаем белый фон для Scaffold
        body: Stack(children: [
          Center(
            child: Stack(
              children: [
                Transform.translate(
                  offset: Offset(0, -60),
                  child: Transform.rotate(
                    angle: -50.33 * 3.14159 / 180, // Angle in radians
                    
                    child: Transform.scale(
                      scale: 2,
                      child: Container(
                        width: 1000, // Line width
                        height: 50, // Line thickness
                        color: Color(0xFF0071BC), // Line color
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 400),
                  child: Transform.rotate(
                    angle: -128.16 * 3.14159 / 180, // Angle in radians

                    child: Transform.scale(
                      scale: 2,
                      child: Container(
                        width: 1000, // Line width
                        height: 50, // Line thickness
                        color: Color(0xFF0071BC), // Line color
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      ),
    );
  }
}
