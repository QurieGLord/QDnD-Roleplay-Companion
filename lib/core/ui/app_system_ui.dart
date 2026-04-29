import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSystemUiOverlay extends StatelessWidget {
  const AppSystemUiOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: styleForTheme(Theme.of(context)),
      child: child,
    );
  }

  static SystemUiOverlayStyle styleForTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    final systemOverlayBrightness = isDark ? Brightness.dark : Brightness.light;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarIconBrightness: iconBrightness,
      statusBarBrightness: systemOverlayBrightness,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }
}
