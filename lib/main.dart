import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/spell_service.dart';
import 'core/services/feature_service.dart';
import 'core/services/character_data_service.dart';
import 'core/services/item_service.dart';
import 'features/splash/splash_screen.dart';
import 'features/character_list/character_list_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const QDnDApp());
}

class QDnDApp extends StatelessWidget {
  const QDnDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QD&D - Roleplay Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const CharacterListScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
