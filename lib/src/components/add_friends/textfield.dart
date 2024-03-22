import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FriendsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const FriendsTextField({
    Key? key,
    required this.controller,
    required this.obscureText,
    required this.hintText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      obscureText: obscureText,
      placeholder: hintText,
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      placeholderStyle: TextStyle(color: Colors.grey),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6, // Для фона текстового поля
        borderRadius: BorderRadius.circular(4), // Скругление углов
      ),
    );
  }
}
