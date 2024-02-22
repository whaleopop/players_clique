import 'package:flutter/material.dart';

class FormFactor {
  static double desktop = 900;
  static double tablet = 600;
  static double handset = 300;

}
enum ScreenSize { small, normal, large, extraLarge }

ScreenSize getSize(BuildContext context) {
  double deviceWidth = MediaQuery.of(context).size.shortestSide;
  if (deviceWidth > 900) return ScreenSize.extraLarge;
  if (deviceWidth > 600) return ScreenSize.large;
  if (deviceWidth > 300) return ScreenSize.normal;
  return ScreenSize.small;
}


