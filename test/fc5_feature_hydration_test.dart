import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_hydration_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/imported_progression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FeatureService.init();
  });

  group('FC5 feature hydration bridge', () {
    test(
      'hydrates imported Paladin Oath of Conquest Channel Divinity mechanics',
      () {
        const xml = '''
<pc version="5">
  <character>
    <name>Conquest Regression</name>
    <abilities>16,10,14,8,10,16</abilities>
    <hpMax>36</hpMax>
    <hpCurrent>36</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Paladin: Oath of Conquest</name>
      <level>4</level>
      <autolevel level="3">
        <feature>
          <name>Channel Divinity</name>
          <text>Your oath allows you to channel divine energy to fuel magical effects.</text>
        </feature>
        <feature>
          <name>Conquering Presence</name>
          <text>You can use your Channel Divinity to exude a terrifying presence. As an action, force creatures of your choice within 30 feet to make a Wisdom saving throw.</text>
        </feature>
        <feature>
          <name>Guided Strike</name>
          <text>When you make an attack roll, you can use your Channel Divinity to gain a +10 bonus to the roll.</text>
        </feature>
      </autolevel>
    </class>
  </character>
</pc>
''';

        final character = FC5Parser.parseCharacter(xml);
        FeatureService.addFeaturesToCharacter(character);
        final result = FeatureHydrationService.hydrateCharacter(character);
        character.features
          ..clear()
          ..addAll(result.features);

        final channelResources = character.features
            .where((feature) =>
                feature.nameEn == 'Channel Divinity' &&
                feature.resourcePool != null)
            .toList();
        expect(channelResources, hasLength(1));
        expect(channelResources.single.id, 'channel-divinity');

        final channelOptions = character.features
            .where((feature) => feature.usageCostId == 'channel-divinity')
            .map((feature) => feature.nameEn)
            .toSet();
        expect(channelOptions,
            containsAll({'Conquering Presence', 'Guided Strike'}));

        final conqueringPresence = character.features.firstWhere(
          (feature) => feature.nameEn == 'Conquering Presence',
        );
        expect(conqueringPresence.resourcePool, isNull);
        expect(conqueringPresence.actionEconomy, 'action');

        final duplicateNames = character.features
            .where((feature) => feature.nameEn == 'Channel Divinity')
            .toList();
        expect(duplicateNames, hasLength(1));
      },
    );

    test('hydrates imported Monk Ki actions and resource pool', () {
      const xml = '''
<pc version="5">
  <character>
    <name>Ki Regression</name>
    <abilities>10,16,14,10,16,8</abilities>
    <hpMax>17</hpMax>
    <hpCurrent>17</hpCurrent>
    <race><name>Human</name></race>
    <class>
      <name>Monk</name>
      <level>2</level>
      <autolevel level="2">
        <feature>
          <name>Ki</name>
          <text>Your access to this energy is represented by a number of ki points.</text>
        </feature>
        <feature>
          <name>Flurry of Blows</name>
          <text>Immediately after you take the Attack action on your turn, you can spend 1 ki point to make two unarmed strikes as a bonus action.</text>
        </feature>
      </autolevel>
    </class>
  </character>
</pc>
''';

      final character = FC5Parser.parseCharacter(xml);
      FeatureService.addFeaturesToCharacter(character);
      final result = FeatureHydrationService.hydrateCharacter(character);
      character.features
        ..clear()
        ..addAll(result.features);

      final ki = character.features.firstWhere((feature) => feature.id == 'ki');
      expect(ki.resourcePool, isNotNull);
      expect(ki.resourcePool!.maxUses, 2);

      final flurry = character.features.firstWhere(
        (feature) => feature.nameEn == 'Flurry of Blows',
      );
      expect(flurry.usageCostId, 'ki');
      expect(flurry.actionEconomy, 'bonus_action');
    });

    test('overlays imported subclass progression onto matching asset class',
        () async {
      const xml = '''
<compendium version="5">
  <class>
    <name>Paladin</name>
    <hd>10</hd>
    <autolevel level="7" subclass="Oath of Conquest">
      <feature>
        <name>Aura of Conquest</name>
        <text>Starting at 7th level, you constantly emanate a menacing aura while you're not incapacitated.</text>
      </feature>
    </autolevel>
  </class>
</compendium>
''';

      final imported = await FC5Parser.parseCompendium(
        xml,
        sourceId: 'conquest-source',
      );

      final assetPaladin = ClassData(
        id: 'paladin',
        name: const {'en': 'Paladin', 'ru': 'Паладин'},
        description: const {'en': 'Asset Paladin', 'ru': 'Паладин'},
        hitDie: 10,
        primaryAbilities: const ['strength', 'charisma'],
        savingThrowProficiencies: const ['wisdom', 'charisma'],
        armorProficiencies: ArmorProficiencies(shields: true),
        weaponProficiencies: WeaponProficiencies(simple: true, martial: true),
        skillProficiencies: SkillProficiencies(
          choose: 2,
          from: const ['athletics', 'insight'],
        ),
        subclasses: const [],
        subclassLevel: 3,
      );

      final overlaid = ImportedProgressionService.overlayImportedClasses(
        assetClasses: [assetPaladin],
        importedClasses: imported.classes,
      );

      final paladin =
          overlaid.singleWhere((classData) => classData.id == 'paladin');
      expect(paladin.sourceId, isNull);
      expect(
        paladin.subclasses.map((subclass) => subclass.name['en']),
        contains('Oath of Conquest'),
      );
      expect(
        paladin.features[7]?.map((feature) => feature.nameEn),
        contains('Aura of Conquest'),
      );
      expect(
        paladin.features[7]?.single.associatedSubclass,
        'Oath of Conquest',
      );
    });

    test('normalizes imported optional feature names and preserves opt-in flag',
        () async {
      const xml = '''
<compendium version="5">
  <class>
    <name>Паладин: Клятва покорения</name>
    <hd>10</hd>
    <autolevel level="7">
      <feature optional="YES">
        <name>[Optional] [Optional] Праведное восстановление, дважды (Опциональное)</name>
        <text>Original optional text stays intact.</text>
      </feature>
    </autolevel>
  </class>
</compendium>
''';

      final imported = await FC5Parser.parseCompendium(
        xml,
        sourceId: 'optional-feature-source',
      );
      final paladin = imported.classes.single;
      final feature = paladin.features[7]!.single;

      expect(feature.nameEn, 'Праведное восстановление, дважды');
      expect(feature.nameRu, 'Праведное восстановление, дважды');
      expect(feature.isOptional, isTrue);
      expect(feature.descriptionEn, contains('Original optional text'));
      expect(feature.associatedSubclass, 'Oath of Conquest');

      final hydrated = FeatureHydrationService.hydrateClassFeatures(
        [feature],
        className: 'Paladin',
        subclassName: feature.associatedSubclass,
      ).features.single;
      expect(hydrated.isOptional, isTrue);
      expect(hydrated.nameEn, 'Праведное восстановление, дважды');
    });
  });

  group('FC5 parser import regressions', () {
    test(
        'canonicalizes proficient and expert skill ids without display duplicates',
        () {
      const xml = '''
<pc version="5">
  <character>
    <name>Skill Canonical</name>
    <abilities>10,10,10,10,10,10</abilities>
    <hpMax>8</hpMax>
    <race><name>Human</name></race>
    <class>
      <name>Rogue</name>
      <level>1</level>
      <proficiency>Insight, Animal Handling, Insight</proficiency>
      <proficiency expert="true">Animal Handling</proficiency>
    </class>
  </character>
</pc>
''';

      final character = FC5Parser.parseCharacter(xml);

      expect(character.proficientSkills,
          containsAll(['insight', 'animal_handling']));
      expect(character.proficientSkills, isNot(contains('Insight')));
      expect(character.proficientSkills, isNot(contains('Animal Handling')));
      expect(character.proficientSkills.toSet(),
          hasLength(character.proficientSkills.length));
      expect(character.expertSkills, ['animal_handling']);
    });

    test('does not double-count candidate diagnostics in warningCount', () {
      const xml = '''
<pc version="5">
  <character>
    <name>Warning Count</name>
    <abilities>10,10</abilities>
    <hpMax>8</hpMax>
    <race><name>Human</name></race>
    <class><name>Fighter</name><level>1</level></class>
  </character>
</pc>
''';

      final result = FC5Parser.parseCharacters(xml);

      expect(result.diagnostics.warningCount, 1);
      expect(result.candidates.single.diagnostics.warningCount, 1);
      expect(result.warningCount, 1);
    });

    test('does not emit imported class spell slots as passive CharacterFeature',
        () async {
      const xml = '''
<compendium version="5">
  <class>
    <name>Fixture Caster</name>
    <hd>8</hd>
    <autolevel level="1">
      <slots>2</slots>
      <feature>
        <name>Fixture Casting</name>
        <text>You can cast fixture spells.</text>
      </feature>
    </autolevel>
  </class>
</compendium>
''';

      final result = await FC5Parser.parseCompendium(
        xml,
        sourceId: 'slot-source',
      );

      final levelOneFeatures = result.classes.single.features[1] ?? const [];
      expect(levelOneFeatures.map((feature) => feature.nameEn),
          contains('Fixture Casting'));
      expect(levelOneFeatures.map((feature) => feature.nameEn),
          isNot(contains('Spell Slots')));
    });
  });
}
