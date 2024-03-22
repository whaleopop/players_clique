import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/icons/player_icon_icons.dart';

import 'package:players_clique/src/pages/screans/map_page.dart';
import 'package:players_clique/src/pages/screans/message_page.dart';
import 'package:players_clique/src/pages/screans/posts_page.dart';
import 'package:players_clique/src/pages/screans/profile_page.dart';
import 'package:players_clique/src/pages/screans/search_page.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePage createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {
  int _selectedIndex = 2;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 2); // Set the initial page to 2 for the third tab
    _pageController.addListener(() {
      setState(() {
        _selectedIndex = _pageController.page!.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:  EdgeInsets.only(bottom: 10.0),
        child: Scaffold(
          bottomNavigationBar: CurvedNavigationBar(
            backgroundColor: Colors.white,
            animationDuration: Duration(milliseconds: 300),
            color: Color(0xFF0071BC),
            buttonBackgroundColor: Colors.lightBlue,
            height: 50,
            index: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
                _pageController.animateToPage(index,
                    duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
              });
            },
            items: [
              Icon(PlayerIcon.play_arrow_fill, color: Colors.white),
              Icon(PlayerIcon.search, color: Colors.white),
              Icon(PlayerIcon.settings_accessibility_fill, color: Colors.white),
              Icon(PlayerIcon.place_black, color: Colors.white),
              Icon(PlayerIcon.chat_fill, color: Colors.white),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: <Widget>[
              Container(child: Posts_Page()),
              Container(child: Search_Page()),
              Container(child: Profile_Page()),
              Container(child: Map_Page()),
              Container(child: Message_Page()),
            ],
          ),
        ),
      ),
    );
  }
}
