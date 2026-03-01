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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              SvgPicture.asset(
                'assets/image/logo.svg',
                height: 70,
              ),
              const SizedBox(height: 10),
              const Text(
                'Players Clique',
                style: TextStyle(
                  color: Color(0xFF0071BC),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Создать аккаунт',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Заполните данные для регистрации',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    MyTextField(
                      controller: fioController,
                      obscureText: false,
                      hintText: 'Имя',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    MyTextField(
                      controller: emailController,
                      obscureText: false,
                      hintText: 'Почта',
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 14),
                    MyTextField(
                      controller: passwordController,
                      obscureText: true,
                      hintText: 'Пароль',
                      prefixIcon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 14),
                    MyTextField(
                      controller: repasswordController,
                      obscureText: true,
                      hintText: 'Подтвердите пароль',
                      prefixIcon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 24),
                    Buttons(onTap: signUp, text: 'Зарегистрироваться'),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: const Text(
                        'Уже есть аккаунт? Войти',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0071BC),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
