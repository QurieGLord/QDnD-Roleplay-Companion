import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';

double _chroma(Color c) {
  final v = [c.r, c.g, c.b]..sort();
  return v.last - v.first;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final preset in AppColorPreset.values) {
      test('Basic mode calms ${preset.name} ($brightness) without replacing it',
          () {
        final full = AppPalettes.getScheme(preset, brightness);
        final calm = AppPalettes.calmScheme(full);
        // Quieter: less colour in surfaces and accents.
        expect(_chroma(calm.primary), lessThan(_chroma(full.primary) + 1e-6));
        expect(_chroma(calm.surface), lessThanOrEqualTo(_chroma(full.surface)));
        // Still the same palette: the leading hue keeps its direction.
        final fullHue = HSVColor.fromColor(full.primary).hue;
        final calmHue = HSVColor.fromColor(calm.primary).hue;
        final d = (fullHue - calmHue).abs() % 360;
        expect(d > 180 ? 360 - d : d, lessThan(12));
        // More readable: quiet text keeps at least 4.5:1 on the page.
        final la = calm.onSurfaceVariant.computeLuminance();
        final lb = calm.surface.computeLuminance();
        final ratio =
            (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
        expect(ratio, greaterThan(4.5));
      });
    }
  }

  test('Calm accents lose colour but keep their order', () {
    final a = AppPalettes.accents(AppColorPreset.monokai, Brightness.dark);
    final calm = AppPalettes.calmAccents(a);
    expect(calm.colors, hasLength(a.colors.length));
    for (var i = 0; i < a.colors.length; i++) {
      expect(_chroma(calm.colors[i]), lessThan(_chroma(a.colors[i])));
    }
  });

  test('AppCalm lerps so glows fade with the theme', () {
    expect(
        const AppCalm(0).lerp(const AppCalm(1), .25).glow, closeTo(.75, 1e-9));
    expect(const AppCalm(1).on, isTrue);
  });
}
