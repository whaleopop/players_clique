import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import '../../services/auth/auth_service.dart';

class MessageProfileAdd extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final Image iconProfile;
  final String uid;

  const MessageProfileAdd({
    Key? key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.uid,

  }) : super(key: key);

  @override
  _MessageProfileAddState createState() => _MessageProfileAddState();
}

class _MessageProfileAddState extends State<MessageProfileAdd> {


  Future<void> _addUidToList() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Await the result of getUserList to get the actual list
    List<String> currentList = await authService.getUserList(widget.uid, 'request');
    String? uid = authService.getCurrentUserUid();

    // Check if the list already contains the uid
    if (!currentList.contains(uid) && uid != null && uid != widget.uid) {
      // If the UID is not in the list and is not the same as the current user's uid, add it
      currentList.add(uid);
      // Update the state with the new list
      setState(() {
        currentList; // Directly assign the list, not a Future
      });

      // Update the Firestore document with the new list
      if (uid != null) {
        await authService.profileListLoad(widget.uid, 'request', currentList);
      }
    } else {
      // Optionally, you can show a message or handle the case where the uid is already in the list or is the same as the current user's uid
      print("UID already exists in the list or is the same as the current user's uid.");
    }
  }



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
            InkWell(
              onTap: _addUidToList,
              child: Container(
                child: Icon(
                  PlayerIcon.person_add_alt,
                  color: Colors.white,
                ),
                height: 50,
                width: 50,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF366837),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
