// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'core/services/storage_service.dart';
import 'core/services/spell_service.dart';
import 'core/services/feature_service.dart';
import 'core/services/character_data_service.dart';
import 'core/services/item_service.dart';
import 'core/services/theme_provider.dart';
import 'core/services/locale_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/character_list/character_list_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;

  try {
    // Initialize storage
    await StorageService.init();

    // Load spells database
    await SpellService.loadSpells();

    // Load class features
    await FeatureService.init();

    // Load character creation data (races, classes, backgrounds)
    await CharacterDataService.loadAllData();

    // Load items database
    await ItemService.loadItems();
  } catch (e, stackTrace) {
    print('❌ CRITICAL ERROR during initialization: $e');
    print(stackTrace);
    initError = '$e\n$stackTrace';
  }

  if (initError != null) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Initialization Failed',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      initError,
                      style: const TextStyle(
                          color: Colors.white70, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const QDnDApp(),
    ),
  );
}

class QDnDApp extends StatelessWidget {
  const QDnDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'QD&D - Roleplay Companion',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ru'), // Russian
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/home': (context) => const CharacterListScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
