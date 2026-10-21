import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Design tokens of the companion. Screens take shape, type and motion from
/// here instead of inventing local values, so every section speaks the same
/// visual language while class panels keep their own composition.

/// Corner scale after the Material 3 Expressive shape scale.
abstract final class AppRadii {
  /// Bars, ticks and other hairline marks.
  static const double xs = 4;

  /// Dense chips and small inline marks.
  static const double sm = 8;

  /// Inline controls and compact tiles.
  static const double md = 12;

  /// List rows and small cards.
  static const double lg = 16;

  /// Fields, menus, snack bars and nested blocks.
  static const double lgPlus = 20;

  /// Cards, dialogs and sheet tops.
  static const double xl = 28;

  /// Hero surfaces and the navigation island.
  static const double xlPlus = 32;

  /// Capsules: chips, buttons at rest, counters.
  static const double pill = 999;

  /// A nested corner stays concentric with its parent.
  static double inner(double outer, double padding) =>
      (outer - padding).clamp(xs, outer);
}

/// Spacing rhythm on a 4 dp grid.
abstract final class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Motion: springs for direct manipulation, curves and durations for
/// transitions. Names are the contract; the numbers may be tuned.
abstract final class AppMotion {
  /// Toggles, tabs and presses: quick with a small overshoot.
  static const snappy = SpringDescription(mass: 1, stiffness: 520, damping: 30);

  /// Drags, swipes and released presses: a visible, playful overshoot.
  static const bouncy = SpringDescription(mass: 1, stiffness: 380, damping: 19);

  /// Large surfaces such as sheets and panels: settles without wobble.
  static const gentle = SpringDescription(mass: 1, stiffness: 220, damping: 27);

  /// Default curve for state changes, expansion and swaps.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Arrival of new content.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Departure: leaving is faster than arriving.
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  static const Duration short = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration long = Duration(milliseconds: 420);
  static const Duration exitDuration = Duration(milliseconds: 180);
  static const Duration stagger = Duration(milliseconds: 45);

  /// Collapses a duration when the system asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// A spring expressed as a [Curve] for implicit animations. Use it only for
/// values that may overshoot (scale, offset, size), never for opacity.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {this.settle = 0.6})
      : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;

  /// Seconds the spring needs to settle; match the animation duration.
  final double settle;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) => _simulation.x(t * settle);
}

/// Three typographic roles: a characterful display face for headings and
/// numbers, a calm body face for reading, and tabular figures for counters.
abstract final class AppType {
  static const String display = 'Rubik';
  static const String body = 'Inter';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Counters, HP, slots and other values that change in place.
  static TextStyle numeric(TextStyle? style) => (style ?? const TextStyle())
      .copyWith(fontFamily: display, fontFeatures: tabular);

  /// Applies the roles to the Material type scale. Sizes follow Material 3;
  /// headings get tight tracking, body text a neutral one tuned for Inter.
  static TextTheme textTheme(TextTheme base) {
    TextStyle? heading(
            TextStyle? s, FontWeight weight, double tracking, double height) =>
        s?.copyWith(
            fontFamily: display,
            fontWeight: weight,
            letterSpacing: tracking,
            height: height,
            fontFeatures: tabular);
    TextStyle? reading(TextStyle? s, double tracking, [FontWeight? weight]) =>
        s?.copyWith(
            fontFamily: body, letterSpacing: tracking, fontWeight: weight);
    return base.copyWith(
      displayLarge: heading(base.displayLarge, FontWeight.w600, -1.4, 1.1),
      displayMedium: heading(base.displayMedium, FontWeight.w600, -1.0, 1.12),
      displaySmall: heading(base.displaySmall, FontWeight.w600, -0.7, 1.16),
      headlineLarge: heading(base.headlineLarge, FontWeight.w600, -0.6, 1.2),
      headlineMedium: heading(base.headlineMedium, FontWeight.w600, -0.5, 1.22),
      headlineSmall: heading(base.headlineSmall, FontWeight.w600, -0.35, 1.25),
      titleLarge: heading(base.titleLarge, FontWeight.w600, -0.3, 1.25),
      titleMedium: heading(base.titleMedium, FontWeight.w600, -0.1, 1.35),
      titleSmall: heading(base.titleSmall, FontWeight.w600, 0, 1.35),
      bodyLarge: reading(base.bodyLarge, -0.1),
      bodyMedium: reading(base.bodyMedium, -0.05),
      bodySmall: reading(base.bodySmall, 0),
      labelLarge: reading(base.labelLarge, 0, FontWeight.w600),
      labelMedium: reading(base.labelMedium, 0.1, FontWeight.w600),
      labelSmall: reading(base.labelSmall, 0.2, FontWeight.w600),
    );
  }
}
