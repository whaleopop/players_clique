import 'package:flutter/material.dart';


class MessageProfile extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final Image iconProfile;
  final String uid;

  const MessageProfile({
    Key? key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.uid,

  }) : super(key: key);

  @override
  _MessageProfileState createState() => _MessageProfileState();
}

class _MessageProfileState extends State<MessageProfile> {




  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 100,
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.fromBorderSide(BorderSide(
            color: Colors.grey,
          )),
        ),
        child: Row(
          textDirection: TextDirection.ltr,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            widget.iconProfile,
            Text(
              widget.text,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: "Arial"),
            ),

          ],
        ),
      ),
    );
  }
}
