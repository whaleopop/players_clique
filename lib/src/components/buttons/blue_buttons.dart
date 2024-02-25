import 'package:flutter/material.dart';

class BlueButtons extends StatelessWidget {
  final void Function()? onTap;
  final String text;

  const BlueButtons({
    super.key,
    required this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(left: 30,right: 30,bottom: 5,top: 5),
          decoration: BoxDecoration(
            color: Color(0xFF0071BC),
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
                  fontSize: 15,
                  fontFamily: "Arial"),
            ),
          ),
        ));
  }
}
