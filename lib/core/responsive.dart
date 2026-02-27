import 'package:flutter/widgets.dart';

class Breakpoints {
  static const desktop = 900.0;
}

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= Breakpoints.desktop;
