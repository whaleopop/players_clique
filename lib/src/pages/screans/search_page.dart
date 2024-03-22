import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';



import '../../icons/player_icon_icons.dart';

class Search_Page extends StatefulWidget {
  @override
  _Search_Page createState() => _Search_Page();
}

class _Search_Page extends State<Search_Page> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          appBar: CupertinoNavigationBar(
            middle: Text('Поиск'),
          )),
    );

  }
}
