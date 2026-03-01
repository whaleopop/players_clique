import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/icons/player_icon_icons.dart';

import 'package:players_clique/src/pages/screans/message_page.dart';
import 'package:players_clique/src/pages/screans/posts_page.dart';
import 'package:players_clique/src/pages/screans/profile_page.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePage createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {
  int _selectedIndex = 1;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
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
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: const Color(0xFFF5F7FA),
        animationDuration: const Duration(milliseconds: 300),
        color: const Color(0xFF0071BC),
        buttonBackgroundColor: const Color(0xFF29ABE2),
        height: 56,
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.animateToPage(index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          });
        },
        items: const [
          Icon(PlayerIcon.play_arrow_fill, color: Colors.white, size: 22),
          Icon(PlayerIcon.settings_accessibility_fill, color: Colors.white, size: 26),
          Icon(PlayerIcon.chat_fill, color: Colors.white, size: 22),
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
          Posts_Page(),
          Profile_Page(),
          Message_Page(),
        ],
      ),
    );
  }
}
