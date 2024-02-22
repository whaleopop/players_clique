import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:players_clique/src/icons/my_flutter_app_icons.dart';
import 'package:players_clique/src/pages/auth/register_page.dart';
import 'package:players_clique/src/pages/screans/map_page.dart';
import 'package:players_clique/src/pages/screans/message_page.dart';
import 'package:players_clique/src/pages/screans/posts_page.dart';
import 'package:players_clique/src/pages/screans/profile_page.dart';
import 'package:players_clique/src/pages/screans/search_page.dart';
import 'package:players_clique/src/pages/start_page.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

import '../components/my_buttons.dart';
import '../components/my_text_field.dart';
import '../components/my_text_link.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePage createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {


  int _selecredIndex = 2;
  List<Widget> _widgetOptions = <Widget>[
    Container(child: Post_Page()),
    Container(child: Search_Page()),
    Container(child: Profile_Page()),
    Container(child: Map_Page()),
    Container(child: Message_Page()),
  ];
  
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey,
            ),
            borderRadius: BorderRadius.all(Radius.circular(20))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15),
          child: GNav(
            activeColor: Colors.white,
            tabBackgroundColor: Color(0xFF0071BC),
            gap: 8,
            selectedIndex: _selecredIndex,
            onTabChange: (index) {
              setState(() {
                _selecredIndex = index;
              });
            },
            padding: EdgeInsets.all(10),
            tabs: [
              GButton(
                icon: MyFlutterApp.like,
                text: "Posts",
              ),
              GButton(
                icon: MyFlutterApp.search,
                text: "Seatch",
              ),
              GButton(
                icon: MyFlutterApp.profile,
                text: "Profile",
              ),
              GButton(
                icon: MyFlutterApp.map,
                text: "Maps",
              ),
              GButton(
                icon: MyFlutterApp.message,
                text: "Message",
              ),
            ],
          ),
        ),
      ),
      body:SafeArea
        (child:_widgetOptions.elementAt(_selecredIndex))
    );
  }
}
