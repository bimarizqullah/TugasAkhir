import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Breakpoints
  static const double _webBreakpoint = 900;

  /// Lebih dari 900px → dianggap Web/Desktop
  static bool isWeb(BuildContext context) =>
      MediaQuery.of(context).size.width >= _webBreakpoint;

  /// Kurang dari 900px → dianggap Mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _webBreakpoint;

  /// Lebar layar saat ini
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
}