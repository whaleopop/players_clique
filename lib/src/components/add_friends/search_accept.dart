import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import '../../services/auth/auth_service.dart';

class MessageProfileAccept extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  final Image iconProfile;
  final String uid;

  const MessageProfileAccept({
    Key? key,
    required this.iconProfile,
    required this.onTap,
    required this.text,
    required this.uid,
  }) : super(key: key);

  @override
  _MessageProfileAcceptState createState() => _MessageProfileAcceptState();
}

class _MessageProfileAcceptState extends State<MessageProfileAccept> {
  Future<void> _removeUidFromList() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Await the result of getUserList to get the actual list
    String? uid = authService.getCurrentUserUid();
    List<String> currentList = await authService.getUserList(uid!, 'request');

    // Check if the list contains the uid
    if (currentList.contains(widget.uid) &&
        widget.uid != null &&
        widget.uid != uid) {
      // If the UID is in the list and is not the same as the current user's uid, remove it
      currentList.remove(widget.uid);
      // Update the state with the new list
      setState(() {
        currentList; // Directly assign the list, not a Future
      });

      // Update the Firestore document with the new list
      if (uid != null) {
        await authService.profileListLoad(uid, 'request', currentList);
      }
    } else {
      // Optionally, you can show a message or handle the case where the uid is not in the list or is the same as the current user's uid
      print(
          "UID does not exist in the list or is the same as the current user's uid.");
    }
  }

  Future<void> _addFriedsUidFromList() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Await the result of getUserList to get the actual list
    String? uid = authService.getCurrentUserUid();
    List<String> requestList = await authService.getUserList(uid!, 'request');
    List<String> requestList1 =
        await authService.getUserList(widget.uid, 'request');

    List<String> friendList = await authService.getUserList(uid!, 'players');
    List<String> friendList1 =
        await authService.getUserList(widget.uid, 'players');

    // Check if the list contains the uid
    if (requestList.contains(widget.uid) &&
        widget.uid != null &&
        widget.uid != uid) {
      // If the UID is in the list and is not the same as the current user's uid, remove it
      requestList.remove(widget.uid);
      requestList1.remove(uid!);
      friendList.add(widget.uid);
      friendList1.add(uid!);
      // Update the state with the new list
      setState(() {
        requestList;
        requestList1;
        friendList;
        friendList1;// Directly assign the list, not a Future
      });

      // Update the Firestore document with the new list
      if (uid != null) {
        await authService.profileListLoad(uid, 'request', requestList);
        await authService.profileListLoad(widget.uid, 'request', requestList1);
        await authService.profileListLoad(uid, 'players', friendList);
        await authService.profileListLoad(widget.uid, 'players', friendList1);
      }
    } else {
      // Optionally, you can show a message or handle the case where the uid is not in the list or is the same as the current user's uid
      print(
          "UID does not exist in the list or is the same as the current user's uid.");
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            widget.iconProfile,
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  widget.text,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: "Arial"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      onTap: _addFriedsUidFromList,
                      child: Container(
                        child: Icon(
                          PlayerIcon.accept_friends,
                          color: Colors.white,
                        ),
                        height: 45,
                        width: 45,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green,
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
                    ),
                    SizedBox(width: 10,),
                    InkWell(
                      onTap: _removeUidFromList,
                      child: Container(
                        child: Icon(
                          PlayerIcon.declaim_friends,
                          color: Colors.white,

                        ),
                        height: 45,
                        width: 45,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red,
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
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
