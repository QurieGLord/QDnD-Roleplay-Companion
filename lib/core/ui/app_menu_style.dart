import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Shared by legacy dropdown routes and Material 3 menus.
/// DropdownButton has no global theme for its route shape, so callers use this.
class AppMenuStyle {
  AppMenuStyle._();
  static const radius = BorderRadius.all(Radius.circular(AppRadii.lgPlus));
  static const shape = RoundedRectangleBorder(borderRadius: radius);
  static Color background(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;
}
