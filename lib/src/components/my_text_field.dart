import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const MyTextField({
    Key? key,
    required this.controller,
    required this.obscureText,
    required this.hintText,

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(4),

        boxShadow: [
          BoxShadow(
            color: Color(0x3F000000).withOpacity(0.5), // Увеличьте прозрачность, если необходимо
            blurRadius:   4,
            offset: Offset(4,   4),
            spreadRadius:   0,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          fillColor: Color(0xFFF4F4F4),
          filled: false,
          border: InputBorder.none, // Удалите границы из InputDecoration
          contentPadding: EdgeInsets.symmetric(vertical:   15,horizontal: 10),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey),

          counterText: '',
          errorMaxLines:   1,
          isDense: false,
        ),
      ),
    );
  }
}
