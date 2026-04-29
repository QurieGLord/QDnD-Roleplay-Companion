import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/app_system_ui.dart';

void main() {
  testWidgets('AppSystemUiOverlay applies transparent edge-to-edge bars',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(),
        home: const AppSystemUiOverlay(
          child: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );

    expect(region.value.statusBarColor, Colors.transparent);
    expect(region.value.systemNavigationBarColor, Colors.transparent);
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarContrastEnforced, isFalse);
  });

  test('AppSystemUiOverlay uses dark system icons for light themes', () {
    final style = AppSystemUiOverlay.styleForTheme(
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink)),
    );

    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });
}
