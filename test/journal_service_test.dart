import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/journal/journal_graph.dart';
import 'package:qd_and_d/core/journal/journal_service.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';

Character hero() => Character(
    id: 'journal-hero',
    name: 'Journal hero',
    race: 'human',
    characterClass: 'fighter',
    level: 1,
    currentHp: 10,
    maxHp: 10,
    spellSlots: [],
    maxSpellSlots: [],
    abilityScores: AbilityScores(
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-journal-state-');
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
      'New catalogue rescans old notes and one save carries metadata and owned media',
      () async {
    final c = hero();
    c.journalNotes.add(JournalNote(
        id: 'old', title: 'Старая встреча', content: 'Мы видели Элиана'));
    await StorageService.saveCharacter(c);
    final events = <BoxEvent>[];
    final sub =
        Hive.box<Character>('characters').watch(key: c.id).listen(events.add);
    final image = File('${dir.path}/picked.png')..writeAsBytesSync([1, 2, 3]);
    final note = JournalNote(
        id: 'new',
        title: 'Элиан',
        content: 'Передать Элиану письмо',
        tags: ['улика'],
        category: NoteCategory.npc,
        isPinned: true,
        imagePath: image.path);
    await JournalService.save(c, JournalEntry.note(note),
        links: JournalRecordLinks(session: 6),
        newEntities: [
          JournalEntity(id: 'e', name: 'Элиан', aliases: ['Elian'])
        ]);
    await Hive.box<Character>('characters').flush();
    expect(events, hasLength(1));
    expect(JournalService.graph(c).forRecord('n:old').automatic, {'e'});
    expect(JournalService.graph(c).forRecord('n:new').session, 6);
    expect(note.imagePath, contains('/journal_media/'));
    await image.delete();
    expect(File(note.imagePath!).readAsBytesSync(), [1, 2, 3]);
    final clone =
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c));
    expect(clone.journalData, c.journalData);
    expect(clone.journalNotes.last.tags, ['улика']);
    expect(clone.journalNotes.last.isPinned, isTrue);
    await sub.cancel();
  });
  test('Exclusions survive rescanning and deleted names cannot linger as links',
      () async {
    final c = hero();
    final note = JournalNote(id: 'n', title: 'Elian');
    await JournalService.save(c, JournalEntry.note(note),
        links: JournalRecordLinks(excluded: {'e'}),
        newEntities: [JournalEntity(id: 'e', name: 'Elian')]);
    expect(JournalService.graph(c).forRecord('n:n').entities, isEmpty);
    await JournalService.updateEntity(
        c, JournalEntity(id: 'e', name: 'Elian', aliases: ['Элиан']));
    expect(JournalService.graph(c).forRecord('n:n').entities, isEmpty);
    await JournalService.deleteEntity(c, 'e');
    expect(JournalService.graph(c).entities, isEmpty);
    expect(c.journalNotes, hasLength(1));
  });
  test(
      'Same-name additions remove former automatic certainty but retain manual choices',
      () async {
    final c = hero();
    final note = JournalNote(id: 'n', title: 'Elian');
    await JournalService.save(c, JournalEntry.note(note),
        links: JournalRecordLinks(),
        newEntities: [JournalEntity(id: 'one', name: 'Elian')]);
    expect(JournalService.graph(c).forRecord('n:n').automatic, {'one'});
    await JournalService.updateEntity(
        c, JournalEntity(id: 'two', name: 'Elian'));
    expect(JournalService.graph(c).forRecord('n:n').automatic, isEmpty);
    await JournalService.save(
        c, JournalEntry.note(JournalNote.fromJson(note.toJson())),
        links: JournalRecordLinks(manual: {'one'}));
    expect(JournalService.graph(c).forRecord('n:n').entities, {'one'});
  });
  test(
      'Queued journal saves and health edits retain both records and gameplay state',
      () async {
    final c = hero();
    await StorageService.saveCharacter(c);
    await Future.wait([
      JournalService.save(
          c, JournalEntry.note(JournalNote(id: 'a', title: 'First')),
          links: JournalRecordLinks()),
      GameplayActionsService.changeHealth(c, 3, healing: false),
      JournalService.save(
          c,
          JournalEntry.quest(Quest(
              id: 'q',
              title: 'Second',
              objectives: [QuestObjective(description: 'Do it')])),
          links: JournalRecordLinks(records: {'n:a'})),
    ]);
    expect(c.currentHp, 7);
    expect(c.journalNotes, hasLength(1));
    expect(c.quests, hasLength(1));
    await JournalService.delete(c, 'n:a');
    expect(JournalService.graph(c).forRecord('q:q').records, isEmpty);
    expect(c.currentHp, 7);
  });
  test(
      'Native Hive reopening preserves graph and cleanup respects shared photos',
      () async {
    final c = hero();
    final picked = File('${dir.path}/shared.png')..writeAsBytesSync([4, 5, 6]);
    await JournalService.save(
        c,
        JournalEntry.note(
            JournalNote(id: 'one', title: 'One', imagePath: picked.path)),
        links: JournalRecordLinks(),
        newEntities: [JournalEntity(id: 'e', name: 'Elian')]);
    final owned = c.journalNotes.single.imagePath!;
    await JournalService.save(
        c,
        JournalEntry.note(
            JournalNote(id: 'two', title: 'Two', imagePath: owned)),
        links: JournalRecordLinks(manual: {'e'}));
    final box = await Hive.openBox<Character>('journal-native-roundtrip');
    await box.put(c.id,
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c)));
    await box.close();
    final reopened = await Hive.openBox<Character>('journal-native-roundtrip');
    expect(reopened.get(c.id)!.journalData, c.journalData);
    await reopened.close();
    await JournalService.delete(c, 'n:one');
    expect(File(owned).existsSync(), isTrue);
    await JournalService.delete(c, 'n:two');
    expect(File(owned).existsSync(), isFalse);
  });

  test('Renaming a story retains its old trusted name and existing mentions',
      () async {
    final c = hero();
    await JournalService.save(
        c, JournalEntry.note(JournalNote(id: 'n', title: 'Elian')),
        links: JournalRecordLinks(),
        newEntities: [JournalEntity(id: 'e', name: 'Elian')]);
    await JournalService.updateEntity(
        c, JournalEntity(id: 'e', name: 'Elian Aldrenborn'));
    expect(JournalService.graph(c).entity('e')!.aliases, contains('Elian'));
    expect(JournalService.graph(c).forRecord('n:n').automatic, {'e'});
  });

  test(
      'Manual order and pinning persist as one action without losing hidden notes',
      () async {
    final c = hero();
    c.journalNotes.addAll([
      JournalNote(id: 'a', title: 'A', isPinned: true),
      JournalNote(id: 'b', title: 'B'),
      JournalNote(id: 'c', title: 'C')
    ]);
    c.quests.addAll(
        [Quest(id: 'one', title: 'One'), Quest(id: 'two', title: 'Two')]);
    await StorageService.saveCharacter(c);
    await JournalService.reorder(c,
        quests: false, visibleOrder: ['n:c', 'n:a'], pinned: {'n:c'});
    expect(c.journalNotes.singleWhere((n) => n.id == 'c').isPinned, isTrue);
    expect(c.journalNotes.singleWhere((n) => n.id == 'a').isPinned, isFalse);
    expect(c.journalNotes.singleWhere((n) => n.id == 'b').isPinned, isFalse);
    expect(JournalService.ordered(c, quests: false).first.key, 'n:c');
    await JournalService.reorder(c,
        quests: true, visibleOrder: ['q:two', 'q:one']);
    expect(JournalService.ordered(c, quests: true).map((e) => e.key),
        ['q:two', 'q:one']);
    final clone =
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c));
    expect(JournalService.graph(clone).noteOrder,
        JournalService.graph(c).noteOrder);
    expect(JournalService.ordered(clone, quests: true).first.key, 'q:two');
    await JournalService.setPinned(c, 'n:c', false);
    expect(c.journalNotes.every((n) => !n.isPinned), isTrue);
  });

  test(
      'Failed reorder restores pin state and order; duplicate projection is rejected',
      () async {
    final c = hero();
    c.journalNotes.addAll([
      JournalNote(id: 'a', title: 'A'),
      JournalNote(id: 'b', title: 'B', isPinned: true)
    ]);
    await StorageService.saveCharacter(c);
    await expectLater(
        JournalService.reorder(c,
            quests: false, visibleOrder: ['n:a', 'n:a'], pinned: {}),
        throwsArgumentError);
    expect(c.journalNotes.last.isPinned, isTrue);
  });

  test('Missing old journal graph is additive and stays empty', () {
    final json = QdndBundleCodec.characterToJson(hero())..remove('journalData');
    expect(QdndBundleCodec.characterFromJson(json).journalData, isEmpty);
  });
  test('Sessions open on the tape and only an empty latest one is taken back',
      () async {
    final c = hero();
    c.journalNotes.add(JournalNote(id: 'n', title: 'At the tavern'));
    c.journalData =
        (JournalGraph(sessions: 1)..forRecord('n:n').session = 2).toJson();
    await StorageService.saveCharacter(c);
    expect(JournalService.graph(c).currentSession, 2);
    await JournalService.startSession(c);
    expect(JournalService.graph(c).currentSession, 3);
    expect(await JournalService.dropSession(c), isTrue);
    expect(JournalService.graph(c).currentSession, 2);
    // Session 2 holds a record: it stays.
    expect(await JournalService.dropSession(c), isFalse);
    expect(JournalService.graph(c).currentSession, 2);
    expect(JournalService.graph(c).forRecord('n:n').session, 2);
  });

  test('Quest steps are ticked and added in one write each', () async {
    final c = hero();
    c.quests.add(Quest(id: 'q', title: 'Find the keeper', objectives: [
      QuestObjective(description: 'Read the letter')
    ]));
    await StorageService.saveCharacter(c);
    await JournalService.setObjective(c, 'q:q', 0, true);
    await JournalService.addObjective(c, 'q:q', '  Ask Mira  ');
    await JournalService.addObjective(c, 'q:q', '   ');
    expect(c.quests.single.objectives.map((o) => o.description),
        ['Read the letter', 'Ask Mira']);
    expect(c.quests.single.objectives.first.isCompleted, isTrue);
  });

  test('Failed writes restore data and clean a newly copied image', () async {
    final c = hero();
    c.journalNotes.addAll([
      JournalNote(id: 'a', title: 'A'),
      JournalNote(id: 'b', title: 'B', isPinned: true)
    ]);
    await StorageService.saveCharacter(c);
    final before = c.updatedAt;
    final image = File('${dir.path}/failure.png')..writeAsBytesSync([1]);
    await Hive.box<Character>('characters').close();
    try {
      await expectLater(
          JournalService.reorder(c,
              quests: false, visibleOrder: ['n:a', 'n:b'], pinned: {'n:a'}),
          throwsA(anything));
      expect(c.journalNotes.first.isPinned, isFalse);
      expect(c.journalNotes.last.isPinned, isTrue);
      await expectLater(
          JournalService.save(
              c,
              JournalEntry.note(
                  JournalNote(id: 'bad', title: 'Bad', imagePath: image.path)),
              links: JournalRecordLinks(),
              newEntities: [JournalEntity(name: 'New')]),
          throwsA(anything));
      expect(c.journalNotes.map((n) => n.id), ['a', 'b']);
      expect(c.journalData, isEmpty);
      expect(c.updatedAt, before);
    } finally {
      await Hive.openBox<Character>('characters');
    }
  });
}
