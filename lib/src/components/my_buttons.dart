import 'package:flutter/material.dart';

class Buttons extends StatelessWidget {
  final void Function()? onTap;
  final String text;

  const Buttons({
    super.key,
    required this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000).withOpacity(0.5),
                // Увеличьте прозрачность, если необходимо
                blurRadius: 4,
                offset: Offset(4, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  fontFamily: "Arial"),
            ),
          ),
        ));
  }
}
