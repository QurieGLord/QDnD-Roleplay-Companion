import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities/abilities_tab_logic.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

Character _buildCharacter({
  required String id,
  required String name,
  required String characterClass,
  List<CharacterFeature>? features,
}) {
  return Character(
    id: id,
    name: name,
    race: 'Human',
    characterClass: characterClass,
    level: 5,
    maxHp: 30,
    currentHp: 30,
    abilityScores: AbilityScores(
      strength: 16,
      dexterity: 14,
      constitution: 14,
      intelligence: 10,
      wisdom: 12,
      charisma: 10,
    ),
    savingThrowProficiencies: const ['strength', 'constitution'],
    spellSlots: const [],
    maxSpellSlots: const [],
    features: features ?? const [],
  );
}

CharacterFeature _resourceFeature({
  required String id,
  required String nameEn,
  required String nameRu,
  int currentUses = 2,
  int maxUses = 3,
  RecoveryType recoveryType = RecoveryType.longRest,
}) {
  return CharacterFeature(
    id: id,
    nameEn: nameEn,
    nameRu: nameRu,
    descriptionEn: '$nameEn description',
    descriptionRu: 'Описание: $nameRu',
    type: FeatureType.resourcePool,
    minLevel: 1,
    resourcePool: ResourcePool(
      currentUses: currentUses,
      maxUses: maxUses,
      recoveryType: recoveryType,
    ),
  );
}

CharacterFeature _activeFeature({
  required String id,
  required String nameEn,
  required String nameRu,
  String? actionEconomy,
}) {
  return CharacterFeature(
    id: id,
    nameEn: nameEn,
    nameRu: nameRu,
    descriptionEn: '$nameEn description',
    descriptionRu: 'Описание: $nameRu',
    type: FeatureType.action,
    minLevel: 1,
    actionEconomy: actionEconomy,
  );
}

Widget _wrap(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AbilitiesTab shell', () {
    testWidgets(
        'renders featured class module before generic sections for dedicated classes',
        (tester) async {
      final character = _buildCharacter(
        id: 'fighter-test',
        name: 'Fighter',
        characterClass: 'Fighter',
        features: [
          _resourceFeature(
            id: 'second_wind',
            nameEn: 'Second Wind',
            nameRu: 'Второе дыхание',
            currentUses: 1,
            maxUses: 1,
            recoveryType: RecoveryType.shortRest,
          ),
          _resourceFeature(
            id: 'combat_superiority',
            nameEn: 'Superiority Dice',
            nameRu: 'Кости превосходства',
            currentUses: 3,
            maxUses: 4,
            recoveryType: RecoveryType.shortRest,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(AbilitiesTab(character: character)));
      await tester.pumpAndSettle();

      final heroFinder = find.byKey(const Key('abilities_featured_modules'));
      final resourcesFinder =
          find.byKey(const Key('abilities_section_resources'));

      expect(heroFinder, findsOneWidget);
      expect(resourcesFinder, findsOneWidget);
      expect(
        tester.getTopLeft(heroFinder).dy,
        lessThan(tester.getTopLeft(resourcesFinder).dy),
      );
    });

    testWidgets(
        'starts with generic section when the class has no dedicated module',
        (tester) async {
      final character = _buildCharacter(
        id: 'custom-test',
        name: 'Custom',
        characterClass: 'Custom Hero',
        features: [
          _resourceFeature(
            id: 'lucky-feet',
            nameEn: 'Lucky Feet',
            nameRu: 'Счастливые ноги',
          ),
        ],
      );

      await tester.pumpWidget(_wrap(AbilitiesTab(character: character)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('abilities_featured_modules')), findsNothing);
      expect(
          find.byKey(const Key('abilities_section_resources')), findsOneWidget);
    });

    testWidgets('renders localized section copy in ru locale', (tester) async {
      final character = _buildCharacter(
        id: 'ru-custom',
        name: 'Custom',
        characterClass: 'Custom Hero',
        features: [
          _resourceFeature(
            id: 'lucky-feet',
            nameEn: 'Lucky Feet',
            nameRu: 'Счастливые ноги',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          AbilitiesTab(character: character),
          locale: const Locale('ru'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ресурсы'), findsOneWidget);
      expect(find.text('Счастливые ноги'), findsOneWidget);
    });

    testWidgets('does not duplicate dedicated fighter features in active list',
        (tester) async {
      final character = _buildCharacter(
        id: 'fighter-dedup',
        name: 'Dedup Fighter',
        characterClass: 'Fighter',
        features: [
          _resourceFeature(
            id: 'second_wind',
            nameEn: 'Second Wind',
            nameRu: 'Второе дыхание',
            currentUses: 1,
            maxUses: 1,
            recoveryType: RecoveryType.shortRest,
          ),
          _resourceFeature(
            id: 'action_surge',
            nameEn: 'Action Surge',
            nameRu: 'Всплеск действий',
            currentUses: 1,
            maxUses: 1,
            recoveryType: RecoveryType.shortRest,
          ),
          _activeFeature(
            id: 'battle-cry',
            nameEn: 'Battle Cry',
            nameRu: 'Боевой клич',
            actionEconomy: 'bonus_action',
          ),
        ],
      );

      await tester.pumpWidget(_wrap(AbilitiesTab(character: character)));
      await tester.pumpAndSettle();

      expect(find.text('Action Surge'), findsOneWidget);
      expect(find.text('Battle Cry'), findsOneWidget);
    });

    testWidgets('does not render a duplicated passive trait text preview',
        (tester) async {
      final character = _buildCharacter(
        id: 'passive-preview',
        name: 'Lorekeeper',
        characterClass: 'Custom Hero',
        features: [
          CharacterFeature(
            id: 'keen-mind',
            nameEn: 'Keen Mind',
            nameRu: 'Острый ум',
            descriptionEn: 'You can accurately recall anything.',
            descriptionRu: 'Вы можете точно вспоминать всё, что видели.',
            type: FeatureType.passive,
            minLevel: 1,
          ),
          CharacterFeature(
            id: 'observant',
            nameEn: 'Observant',
            nameRu: 'Наблюдательность',
            descriptionEn: 'You notice important details around you.',
            descriptionRu: 'Вы замечаете важные детали вокруг себя.',
            type: FeatureType.passive,
            minLevel: 1,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(AbilitiesTab(character: character)));
      await tester.pumpAndSettle();

      expect(find.text('Keen Mind • Observant'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('abilities_section_passive')),
          matching: find.byIcon(Icons.expand_more),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keen Mind'), findsOneWidget);
      expect(find.text('Observant'), findsOneWidget);
    });
  });

  group('AbilitiesTabLogic', () {
    test('hides dedicated fighter features from generic rendering', () {
      final character = _buildCharacter(
        id: 'logic-fighter',
        name: 'Logic Fighter',
        characterClass: 'Fighter',
        features: const [],
      );
      final logic = AbilitiesTabLogic(character);

      final actionSurge = _resourceFeature(
        id: 'action_surge',
        nameEn: 'Action Surge',
        nameRu: 'Всплеск действий',
      );

      expect(logic.shouldShowInList(actionSurge), isFalse);
    });

    test('keeps the highest-level duplicate when localized names match', () {
      final character = _buildCharacter(
        id: 'logic-duplicates',
        name: 'Logic Cleric',
        characterClass: 'Cleric',
        features: const [],
      );
      final logic = AbilitiesTabLogic(character);

      final lower = CharacterFeature(
        id: 'destroy-undead-cr-1-2',
        nameEn: 'Destroy Undead (CR 1/2)',
        nameRu: 'Уничтожение нежити (Оп 1/2)',
        descriptionEn: 'Lower tier',
        descriptionRu: 'Младшая версия',
        type: FeatureType.passive,
        minLevel: 5,
      );
      final higher = CharacterFeature(
        id: 'destroy-undead-cr-1',
        nameEn: 'Destroy Undead (CR 1)',
        nameRu: 'Уничтожение нежити (Оп 1)',
        descriptionEn: 'Higher tier',
        descriptionRu: 'Старшая версия',
        type: FeatureType.passive,
        minLevel: 8,
      );

      final deduped = logic.deduplicateAndFilterFeatures(
        [lower, higher],
        'en',
      );

      expect(deduped, hasLength(1));
      expect(deduped.single.id, higher.id);
    });
  });
}
