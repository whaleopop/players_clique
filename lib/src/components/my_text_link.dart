import 'package:flutter/material.dart';

class TextTap extends StatelessWidget {
  final void Function()? onTap;
  final String text;

  const TextTap({
    super.key,
    required this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(

          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: "Arial",
                  decoration: TextDecoration.underline),
            ),
          ),
        ));
  }
}
