import 'package:flutter/material.dart';

/// Shared by legacy dropdown routes and Material 3 menus.
/// DropdownButton has no global theme for its route shape, so callers use this.
class AppMenuStyle {
  AppMenuStyle._();
  static const radius = BorderRadius.all(Radius.circular(22));
  static const shape = RoundedRectangleBorder(borderRadius: radius);
  static Color background(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;
}
