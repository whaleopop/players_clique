import 'package:flutter/material.dart';

class MessageProfile extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  final Image iconProfile;

  const MessageProfile({
    super.key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          padding: EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.fromBorderSide(BorderSide(
              color: Colors.grey,
            )),
          ),
          child: Row(
            children: [
              this.iconProfile,
              Text(
                  text,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      fontFamily: "Arial"),
              ),
            ],
          )
        ));
  }
}
