import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/progression/level_up_commit.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-level-commit-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  setUp(() async => Hive.box<Character>('characters').clear());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'Confirmation saves one coherent development result without touching the journal or active sheet state',
      () async {
    final c = fixtures.hero()
      ..currentHp = 0
      ..temporaryHp = 7
      ..goldPieces = 450;
    c.journalNotes.add(JournalNote(id: 'n', title: 'An old memory'));
    await StorageService.saveCharacter(c);
    final note = c.journalNotes.single;
    final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
    var writes = 0;
    await LevelUpCommit.apply(c, baseline: draft, result: draft.preview,
        write: (value) async {
      writes++;
      expect(value.level, 2);
      expect(value.classes.single.level, 2);
      expect(value.maxHp, 16);
      expect(value.currentHp, 0);
      await StorageService.saveCharacter(value);
    });
    expect(writes, 1);
    expect(c.journalNotes.single, same(note));
    expect(c.goldPieces, 450);
    expect(c.temporaryHp, 7);
    final box = await Hive.openBox<Character>('level-up-native-roundtrip');
    await box.put(c.id, QdndBundleCodec.cloneCharacter(c));
    await box.close();
    final reopened = await Hive.openBox<Character>('level-up-native-roundtrip');
    expect(reopened.get(c.id)!.level, 2);
    expect(reopened.get(c.id)!.currentHp, 0);
    expect(reopened.get(c.id)!.journalNotes.single.title, 'An old memory');
    await reopened.close();
  });
  test(
      'A failed write restores every proposed development field and allows retry',
      () async {
    final c = fixtures.hero()
      ..armorClass = 19
      ..spellSlots = [6]
      ..maxSpellSlots = [4];
    await StorageService.saveCharacter(c);
    final before = QdndBundleCodec.characterToJson(c);
    final draft = LevelUpDraft.begin(c, classId: 'fighter')
      ..chooseHealth(6)
      ..chooseSharedSlotMaximums([5]);
    final proposed = draft.preview
      ..proficientSkills = ['athletics']
      ..expertSkills = ['athletics']
      ..maxHitDice = 2
      ..hitDice = [2];
    await expectLater(
        LevelUpCommit.apply(c,
            baseline: draft,
            result: proposed,
            write: (_) async => throw const FileSystemException('No space')),
        throwsA(isA<FileSystemException>()));
    expect(QdndBundleCodec.characterToJson(c), before);
    await LevelUpCommit.apply(c, baseline: draft, result: proposed);
    expect(c.level, 2);
    expect(c.spellSlots, [7]);
    expect(c.armorClass, 19);
    expect(c.expertSkills, ['athletics']);
  });
  test(
      'Queued health action invalidates an older preview without undoing the health action',
      () async {
    final c = fixtures.hero();
    await StorageService.saveCharacter(c);
    final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
    final damage = GameplayActionsService.changeHealth(c, 3, healing: false);
    final commit =
        LevelUpCommit.apply(c, baseline: draft, result: draft.preview);
    final rejected = expectLater(commit, throwsStateError);
    await damage;
    await rejected;
    expect(c.currentHp, 7);
    expect(c.level, 1);
    expect(c.maxHp, 10);
  });
  test('Two confirmations of the same preview cannot grant two levels',
      () async {
    final c = fixtures.hero();
    await StorageService.saveCharacter(c);
    final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
    final first =
        LevelUpCommit.apply(c, baseline: draft, result: draft.preview);
    final second =
        LevelUpCommit.apply(c, baseline: draft, result: draft.preview);
    final rejected = expectLater(second, throwsStateError);
    await first;
    await rejected;
    expect(c.level, 2);
    expect(c.maxHp, 16);
  });
  test('Tampered or incomplete class results are rejected before any write',
      () async {
    final c = fixtures.hero();
    final before = QdndBundleCodec.characterToJson(c);
    final draft = LevelUpDraft.begin(c, classId: 'fighter')..chooseHealth(6);
    final bad = draft.preview..currentHp = 16;
    var writes = 0;
    await expectLater(
        LevelUpCommit.apply(c, baseline: draft, result: bad, write: (_) async {
          writes++;
        }),
        throwsStateError);
    expect(writes, 0);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
}
