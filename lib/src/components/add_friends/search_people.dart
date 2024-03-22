import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import '../../services/auth/auth_service.dart';

class ProfilePlayerPreview extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final Image iconProfile;
  final String uid;

  const ProfilePlayerPreview({
    Key? key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.uid,

  }) : super(key: key);

  @override
  _ProfilePlayer createState() => _ProfilePlayer();
}

class _ProfilePlayer extends State<ProfilePlayerPreview> {

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 100,
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.only(left: 30,right: 30,top: 10,bottom: 10),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 80, // Задайте желаемый размер иконки
              height: 80, // Задайте желаемый размер иконки
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image(
                  image: widget.iconProfile.image, // Используйте свойство image из ImageProvider
                  fit: BoxFit.cover, // Установите BoxFit.cover
                ),
              ),
            ),
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
