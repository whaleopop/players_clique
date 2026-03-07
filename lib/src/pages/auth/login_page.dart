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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              SvgPicture.asset(
                'assets/image/logo.svg',
                height: 80,
              ),
              const SizedBox(height: 12),
              const Text(
                'РКН Российская Коммуна Никиты',
                style: TextStyle(
                  color: Color(0xFF366837),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                      'Добро пожаловать',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Войдите в свой аккаунт',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    MyTextField(
                      controller: emailController,
                      obscureText: false,
                      hintText: 'Почта',
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    MyTextField(
                      controller: passwordController,
                      obscureText: true,
                      hintText: 'Пароль',
                      prefixIcon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 28),
                    Buttons(onTap: signIn, text: 'Войти'),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: const Text(
                        'Ещё нет аккаунта? Зарегистрироваться',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF366837),
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
