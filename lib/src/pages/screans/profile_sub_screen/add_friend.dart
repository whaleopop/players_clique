import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/buttons/blue_buttons_icon.dart';
import 'package:players_clique/src/components/my_text_field.dart';
import 'package:players_clique/src/icons/player_icon_icons.dart';
import 'package:players_clique/src/pages/screans/profile_sub_screen/friend_people_list.dart';
import 'package:players_clique/src/pages/screans/profile_sub_screen/request_people_list.dart';
import 'package:provider/provider.dart';

import '../../../components/add_friends/search_accept.dart';


import '../../../components/add_friends/seatch_add.dart';
import '../../../components/add_friends/textfield.dart';
import '../../../services/auth/auth_service.dart';
import '../chat/chat_page.dart';
import 'all_people_list.dart';

class Add_Friends_Page extends StatefulWidget {
  @override
  _Add_Friends_Page createState() => _Add_Friends_Page();
}

class _Add_Friends_Page extends State<Add_Friends_Page> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
          appBar: CupertinoNavigationBar(
            middle: Text(''),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(10.0), // Add padding around the button
                  child: BlueButtonsIcon(onTap: (){
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => AllPeopleList()),
                    );
                  }, text: "Поиск друзей", width: 300, icon: Icon(PlayerIcon.person_add_alt,color: Colors.white,)),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0), // Add padding around the button
                  child: BlueButtonsIcon(onTap: (){

                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => RequestPeople()),
                    );
                  }, text: "Заявки в друзья", width: 300, icon: Icon(PlayerIcon.person_add_alt,color: Colors.white,)),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0), // Add padding around the button
                  child: BlueButtonsIcon(onTap: (){
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => FriendPeople()),
                    );
                  }, text: "Список друзей", width: 300, icon: Icon(PlayerIcon.person_add_alt,color: Colors.white,)),
                ),
              ],
            ),
          ),
        ));
  }


}


