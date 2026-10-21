import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/sorcery_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'journal_service_test.dart' as fixtures;

Character hero() {
  final c = fixtures.hero()
    ..characterClass = 'sorcerer'
    ..level = 2
    ..spellSlots = [1]
    ..maxSpellSlots = [3];
  c.classes = [
    CharacterClass(id: 'sorcerer', name: 'Sorcerer', level: 2, isPrimary: true)
  ];
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-sorcery-actions-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test('Missing pool is read-only and an explicit edit owns its remainder',
      () async {
    final c = hero();
    final before = QdndBundleCodec.characterToJson(c);
    expect(SorceryActionsService.view(c).currentUses, 0);
    expect(c.features, isEmpty);
    expect(QdndBundleCodec.characterToJson(c), before);
    await SorceryActionsService.setCurrent(c, 6);
    expect(SorceryActionsService.view(c).currentUses, 6);
    expect(c.features.single.resourcePool!.maxUses, 2);
    expect(
        StorageService.getCharacter(c.id)!
            .features
            .single
            .resourcePool!
            .currentUses,
        6);
  });
  test(
      'Explicit rest restores a declared missing pool while previewing it stays detached',
      () async {
    final c = hero();
    c.features.add(
        FeatureService.getFeatureById('font-of-magic')!.copyForCharacter()
          ..resourcePool = null);
    final before = QdndBundleCodec.characterToJson(c);
    final preview = QdndBundleCodec.cloneCharacter(c);
    FeatureService.prepareKnownResourcePools(preview);
    preview.longRest();
    expect(SorceryActionsService.view(preview).currentUses, 2);
    expect(QdndBundleCodec.characterToJson(c), before);
    await GameplayActionsService.rest(c, short: false);
    expect(SorceryActionsService.view(c).currentUses, 2);
    expect(c.features.single.resourcePool!.maxUses, 2);
  });
  test(
      'Consuming a slot explicitly acquires a missing remainder without a hidden full refill',
      () async {
    final c = hero();
    var writes = 0;
    await SorceryActionsService.convert(c, 1, creating: false,
        write: (value) async {
      writes++;
      await StorageService.saveCharacter(value);
    });
    expect(writes, 1);
    expect(c.spellSlots, [0]);
    expect(SorceryActionsService.view(c).currentUses, 1);
  });
  test(
      'Creation above the usual spell capacity retains overfill and uses the table price',
      () async {
    final c = hero();
    await SorceryActionsService.setCurrent(c, 8);
    await SorceryActionsService.convert(c, 5, creating: true);
    expect(c.spellSlots, [1, 0, 0, 0, 1]);
    expect(c.maxSpellSlots, [3]);
    expect(SorceryActionsService.view(c).currentUses, 1);
  });
  test(
      'Conversion failure restores both resource ownership and the consumed slot',
      () async {
    final c = hero();
    final before = QdndBundleCodec.characterToJson(c);
    await expectLater(
        SorceryActionsService.convert(c, 1,
            creating: false,
            write: (_) async => throw const FileSystemException('No space')),
        throwsA(isA<FileSystemException>()));
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  test('Insufficient resource never creates a slot or a phantom saved pool',
      () async {
    final c = hero();
    final before = QdndBundleCodec.characterToJson(c);
    expect(await SorceryActionsService.convert(c, 1, creating: true), isFalse);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  test(
      'Conversion keeps explicit excess and a priced action cannot become cheaper',
      () async {
    final c = hero();
    await SorceryActionsService.setCurrent(c, 6);
    await SorceryActionsService.convert(c, 1, creating: false);
    expect(SorceryActionsService.view(c).currentUses, 7);
    await SorceryActionsService.setCurrent(c, 1);
    expect(await SorceryActionsService.spend(c, 2), isFalse);
    expect(SorceryActionsService.view(c).currentUses, 1);
  });
}
