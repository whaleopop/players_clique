import 'dart:async';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/icons/player_icon_icons.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

import 'package:players_clique/src/pages/screans/message_page.dart';
import 'package:players_clique/src/pages/screans/posts_page.dart';
import 'package:players_clique/src/pages/screans/profile_page.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePage createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {
  int _selectedIndex = 1;
  late PageController _pageController;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _pageController.addListener(() {
      setState(() => _selectedIndex = _pageController.page!.round());
    });
    // Update presence immediately then every 3 minutes
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePresence());
    _presenceTimer =
        Timer.periodic(const Duration(minutes: 3), (_) => _updatePresence());
  }

  void _updatePresence() {
    final auth = Provider.of<AuthService>(context, listen: false);
    auth.updatePresence();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
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
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        },
        items: const [
          Icon(PlayerIcon.play_arrow_fill, color: Colors.white, size: 22),
          Icon(PlayerIcon.settings_accessibility_fill,
              color: Colors.white, size: 26),
          Icon(PlayerIcon.chat_fill, color: Colors.white, size: 22),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: <Widget>[
          Posts_Page(),
          Profile_Page(),
          Message_Page(),
        ],
      ),
    );
  }
}
