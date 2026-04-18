import 'package:flutter/material.dart';

class AbilitiesShellTokens {
  const AbilitiesShellTokens._();

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 96);
  static const EdgeInsets sectionPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  static const EdgeInsets nestedPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  static const double heroSpacing = 12;
  static const double sectionSpacing = 20;
  static const double itemSpacing = 12;
  static const double compactSpacing = 8;

  static const double sectionRadius = 28;
  static const double nestedRadius = 22;
  static const double itemRadius = 20;
  static const double pillRadius = 999;

  static const Duration pressDuration = Duration(milliseconds: 120);
  static const Duration revealDuration = Duration(milliseconds: 420);
  static const Duration expandDuration = Duration(milliseconds: 220);
  static const Duration scrollDuration = Duration(milliseconds: 420);

  static const Curve revealCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve emphasisCurve = Curves.easeOutQuart;
}
