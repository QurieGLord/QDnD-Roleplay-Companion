import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/ui/app_scroll_behavior.dart';
import 'core/ui/app_system_ui.dart';
import 'features/journal_cycle/journal_cycle_screen.dart';

/// Built only for the separate Cycle package. No storage is opened or migrated.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const JournalCycleApp());
}

class JournalCycleApp extends StatelessWidget {
  const JournalCycleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QDnD Cycle Test',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        scrollBehavior: const AppScrollBehavior(),
        builder: (context, child) => AppSystemUiOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const JournalCycleScreen(),
      );
}
