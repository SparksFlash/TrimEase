import 'package:flutter/widgets.dart';

class AppWidget {
  static TextStyle healineTextStyle(double size) {
    return TextStyle(
      color: Color(0xff2c3925),
      fontWeight: FontWeight.bold,
      fontSize: size,
    );
  }

  static TextStyle greenTextStyle(double size) {
    return TextStyle(
      color: Color(0xff2c3925),
      fontSize: size,
      fontWeight: FontWeight.bold,
    );
  }


  static TextStyle headlineTextStyle(double fontSize) {
    return TextStyle(
      color: const Color(0xFF2C3925),
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );
  }
}