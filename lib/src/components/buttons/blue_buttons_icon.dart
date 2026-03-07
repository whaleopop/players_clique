import 'package:flutter/material.dart';

class BlueButtonsIcon extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  final double width;
  final Icon icon;

  const BlueButtonsIcon({
    Key? key,
    required this.onTap,
    required this.text, required this.width, required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        width: width, // Задайте желаемую ширину кнопки
        child: Container(
          padding: EdgeInsets.only(left: 30, right: 30, bottom: 5, top: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF366837),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000).withOpacity(0.5), // Увеличьте прозрачность, если необходимо
                blurRadius: 4,
                offset: Offset(4, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              icon, // Используйте переданную иконку
              SizedBox(width: 10), // Добавьте отступ между иконкой и текстом
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: "Arial",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
