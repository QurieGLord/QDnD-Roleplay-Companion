import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';

void main() {
  testWidgets('AppSnackBar renders floating rounded snackbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    AppSnackBar.error(
                      context,
                      'Something went wrong',
                      actionLabel: 'Retry',
                      onAction: () {},
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.dismissDirection, DismissDirection.horizontal);
    expect(snackBar.duration.inSeconds, greaterThan(0));
    expect(snackBar.duration.inDays, 0);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());
    expect(snackBar.margin, isA<EdgeInsets>());
  });

  testWidgets('AppSnackBar success tone stays soft on Monokai', (tester) async {
    final scheme = AppPalettes.getScheme(
      AppColorPreset.monokai,
      Brightness.dark,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  AppSnackBar.success(context, 'Saved');
                },
                child: const Text('Show'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, isNot(scheme.primary));
    expect(snackBar.backgroundColor, isNot(const Color(0xFFA6E22E)));
    expect(snackBar.duration.inSeconds, greaterThan(0));
    expect(snackBar.dismissDirection, DismissDirection.horizontal);
  });
}
