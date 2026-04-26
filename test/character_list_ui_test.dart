import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/features/character_list/character_list_screen.dart';
import 'package:qd_and_d/features/character_list/widgets/character_card.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('character card is compact and has no trailing arrow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 328,
          child: CharacterCard(
            character: _character(
              name: 'Rowan of the Extremely Long Violet Archive and Glass Moon',
              race: 'Dragonborn',
              characterClass: 'Paladin',
              subclass: 'Oath of the Longest Possible Synthetic Test Name',
            ),
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.textContaining('Level 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export format picker exposes QDND and FC5 choices',
      (tester) async {
    var qdndTapped = false;
    var fc5Tapped = false;

    await tester.pumpWidget(
      _wrap(
        CharacterExportOptionsContent(
          onQdndBundle: () => qdndTapped = true,
          onFc5Xml: () => fc5Tapped = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Export QDND Bundle'), findsOneWidget);
    expect(find.text('FC5 XML'), findsOneWidget);

    await tester.tap(find.text('Export QDND Bundle'));
    await tester.tap(find.text('FC5 XML'));
    expect(qdndTapped, isTrue);
    expect(fc5Tapped, isTrue);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: child is CharacterListScreen
        ? child
        : Scaffold(body: Center(child: child)),
  );
}

Character _character({
  String name = 'Crimson Rowan',
  String race = 'Human',
  String characterClass = 'Fighter',
  String? subclass = 'Champion',
}) {
  return Character(
    id: 'ui-character',
    name: name,
    race: race,
    characterClass: characterClass,
    subclass: subclass,
    level: 4,
    maxHp: 34,
    currentHp: 28,
    abilityScores: AbilityScores(
      strength: 16,
      dexterity: 12,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    ),
    spellSlots: List.filled(9, 0),
    maxSpellSlots: List.filled(9, 0),
    armorClass: 17,
    speed: 30,
    initiative: 1,
    classes: [
      CharacterClass(
        id: characterClass.toLowerCase(),
        name: characterClass,
        level: 4,
        subclass: subclass,
        isPrimary: true,
      ),
    ],
  );
}
