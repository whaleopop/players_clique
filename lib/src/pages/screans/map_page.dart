import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../icons/player_icon_icons.dart';

class Map_Page extends StatefulWidget {
  @override
  _Map_Page createState() => _Map_Page();
}

class _Map_Page extends State<Map_Page> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          appBar: CupertinoNavigationBar(
            middle: Text('Карта'),
          )),
    );

  }
}
