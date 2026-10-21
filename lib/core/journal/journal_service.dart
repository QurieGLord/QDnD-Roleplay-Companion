import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/journal_note.dart';
import '../models/quest.dart';
import '../services/gameplay_actions_service.dart';
import '../services/storage_service.dart';
import 'journal_graph.dart';
import 'journal_links.dart';

class JournalEntry {
  JournalEntry.note(this.note) : quest = null;
  JournalEntry.quest(this.quest) : note = null;
  final JournalNote? note;
  final Quest? quest;
  String get key => note != null ? 'n:${note!.id}' : 'q:${quest!.id}';
  String get title => note?.title ?? quest!.title;
  String get text => note?.content ?? quest!.description;
  String? get image => note?.imagePath ?? quest?.imagePath;
  DateTime get date => note?.createdAt ?? quest!.createdAt;
  List<String> get fields => [
        title,
        text,
        ...?note?.tags,
        if (note != null) note!.category.displayName,
        if (note != null) note!.category.displayNameRu,
        ...?quest?.objectives.map((o) => o.description)
      ];
}

class JournalService {
  static List<JournalEntry> entries(Character c) => [
        ...c.quests.map(JournalEntry.quest),
        ...c.journalNotes.map(JournalEntry.note)
      ];
  static JournalGraph graph(Character c) =>
      JournalGraph.fromJson(c.journalData);
  static void reconcile(Character c, JournalGraph graph) {
    final all = entries(c);
    final keys = all.map((e) => e.key).toSet();
    for (final key in graph.records.keys.toList()) {
      if (!keys.contains(key)) graph.removeRecord(key);
    }
    final matcher = JournalMatcher(graph.entities);
    for (final entry in all) {
      final links = graph.forRecord(entry.key);
      final analysis = matcher.analyze(entry.fields.join('\n'));
      links.automatic = analysis.automatic.difference(links.excluded);
      links.records
          .removeWhere((key) => !keys.contains(key) || key == entry.key);
      links.manual.removeWhere((id) => graph.entity(id) == null);
    }
  }

  static Future<void> _mutate(
          Character c, Future<void> Function(JournalGraph) action) =>
      GameplayActionsService.serializeCharacter(c, () async {
        final notes = List<JournalNote>.of(c.journalNotes);
        final quests = List<Quest>.of(c.quests);
        final data = c.journalData;
        final time = c.updatedAt;
        try {
          final g = graph(c);
          await action(g);
          reconcile(c, g);
          c.journalData = g.toJson();
          await StorageService.saveCharacter(c);
        } catch (_) {
          c.journalNotes = notes;
          c.quests = quests;
          c.journalData = data;
          c.updatedAt = time;
          rethrow;
        }
        // Cleanup is after commit; its failure must never undo a successful save.
        try {
          await _cleanUnused([
            ...notes.map((n) => n.imagePath),
            ...quests.map((q) => q.imagePath)
          ]);
        } catch (_) {/* Keep an orphan rather than risk a saved attachment. */}
      });

  static Future<void> save(Character c, JournalEntry entry,
      {required JournalRecordLinks links,
      List<JournalEntity> newEntities = const []}) async {
    String? copied;
    final image = entry.image;
    if (image != null &&
        image.isNotEmpty &&
        !image.startsWith('http') &&
        !await _managed(image)) {
      copied = await _copyImage(image);
      if (entry.note != null) entry.note!.imagePath = copied;
      if (entry.quest != null) entry.quest!.imagePath = copied;
    }
    try {
      await _mutate(c, (g) async {
        for (final entity in newEntities) {
          if (g.entity(entity.id) == null) g.entities.add(entity);
        }
        g.records[entry.key] = JournalRecordLinks.fromJson(links.toJson());
        if (entry.note != null) {
          entry.note!.updatedAt = DateTime.now();
          c.journalNotes.removeWhere((n) => n.id == entry.note!.id);
          c.journalNotes.add(entry.note!);
        } else {
          c.quests.removeWhere((q) => q.id == entry.quest!.id);
          c.quests.add(entry.quest!);
        }
      });
    } catch (_) {
      if (copied != null) {
        try {
          await File(copied).delete();
        } catch (_) {/* Orphan can be cleaned later. */}
        if (entry.note != null) entry.note!.imagePath = image;
        if (entry.quest != null) entry.quest!.imagePath = image;
      }
      rethrow;
    }
  }

  static List<JournalEntry> ordered(Character c, {required bool quests}) {
    final g = graph(c);
    final order = quests ? g.questOrder : g.noteOrder;
    final positions = {for (var i = 0; i < order.length; i++) order[i]: i};
    final list = entries(c)
        .where((e) => quests ? e.quest != null : e.note != null)
        .toList();
    list.sort((a, b) {
      if (!quests) {
        final pin =
            (a.note!.isPinned ? 0 : 1).compareTo(b.note!.isPinned ? 0 : 1);
        if (pin != 0) return pin;
      } else if (order.isEmpty) {
        final active = (a.quest!.status == QuestStatus.active ? 0 : 1)
            .compareTo(b.quest!.status == QuestStatus.active ? 0 : 1);
        if (active != 0) return active;
      }
      if (order.isNotEmpty) {
        final position =
            (positions[a.key] ?? -1).compareTo(positions[b.key] ?? -1);
        if (position != 0) return position;
      }
      return (b.note?.updatedAt ?? b.date)
          .compareTo(a.note?.updatedAt ?? a.date);
    });
    return list;
  }

  static Future<void> setPinned(Character c, String key, bool pinned) =>
      _mutate(c, (g) async {
        final index =
            c.journalNotes.indexWhere((note) => 'n:${note.id}' == key);
        if (index < 0) return;
        final current = ordered(c, quests: false).map((e) => e.key).toList();
        final copy = JournalNote.fromJson(c.journalNotes[index].toJson())
          ..isPinned = pinned;
        c.journalNotes[index] = copy;
        g.noteOrder
          ..clear()
          ..addAll(current)
          ..remove(key)
          ..insert(0, key);
      });

  static Future<void> setQuestStatus(
          Character c, String key, QuestStatus status) =>
      _mutate(c, (g) async {
        final index = c.quests.indexWhere((quest) => 'q:${quest.id}' == key);
        if (index < 0) return;
        final copy = Quest.fromJson(c.quests[index].toJson())..status = status;
        copy.completedAt = status == QuestStatus.active ? null : DateTime.now();
        c.quests[index] = copy;
      });

  /// A visible projection is reordered without moving or dropping hidden records.
  /// Notes before the UI boundary are pinned; the same write stores their order.
  static Future<void> reorder(Character c,
          {required bool quests,
          required List<String> visibleOrder,
          Set<String>? pinned}) =>
      _mutate(c, (g) async {
        final before = ordered(c, quests: quests).map((e) => e.key).toList();
        final visible = visibleOrder.toSet();
        if (visible.length != visibleOrder.length ||
            !before.toSet().containsAll(visible)) {
          throw ArgumentError('Invalid journal order');
        }
        var at = 0;
        final merged = [
          for (final key in before)
            visible.contains(key) ? visibleOrder[at++] : key
        ];
        final order = quests ? g.questOrder : g.noteOrder;
        order
          ..clear()
          ..addAll(merged);
        if (!quests && pinned != null) {
          for (var i = 0; i < c.journalNotes.length; i++) {
            final key = 'n:${c.journalNotes[i].id}';
            if (!visible.contains(key)) continue;
            c.journalNotes[i] = JournalNote.fromJson(c.journalNotes[i].toJson())
              ..isPinned = pinned.contains(key);
          }
        }
      });

  static Future<void> delete(Character c, String key) => _mutate(c, (g) async {
        c.journalNotes.removeWhere((n) => 'n:${n.id}' == key);
        c.quests.removeWhere((q) => 'q:${q.id}' == key);
        g.removeRecord(key);
      });

  static Future<void> updateEntity(Character c, JournalEntity entity) =>
      _mutate(c, (g) async {
        final old = g.entity(entity.id);
        if (old != null &&
            old.name != entity.name &&
            !entity.aliases.contains(old.name)) {
          entity.aliases.add(old.name);
        }
        g.entities.removeWhere((e) => e.id == entity.id);
        g.entities.add(entity);
      });
  static Future<void> deleteEntity(Character c, String id) =>
      _mutate(c, (g) async => g.removeEntity(id));

  static Future<bool> _managed(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return path.isWithin(path.join(dir.path, 'journal_media'),
        path.normalize(path.absolute(filename)));
  }

  static Future<void> _cleanUnused(List<String?> candidates) async {
    final used = <String>{};
    for (final c in StorageService.getAllCharacters()) {
      used.addAll([
        ...c.journalNotes.map((n) => n.imagePath),
        ...c.quests.map((q) => q.imagePath),
        c.avatarPath,
        ...c.inventory.map((item) => item.customImagePath)
      ].whereType<String>().map((f) => path.normalize(path.absolute(f))));
    }
    for (final filename in candidates.whereType<String>().toSet()) {
      if (!filename.startsWith('http') &&
          await _managed(filename) &&
          !used.contains(path.normalize(path.absolute(filename)))) {
        final file = File(filename);
        if (await file.exists()) await file.delete();
      }
    }
  }

  static Future<String> _copyImage(String path) async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory('${dir.path}/journal_media');
    await media.create(recursive: true);
    // Image validation/decoding belongs to the picker; preserve the selected bytes.
    final extension =
        path.contains('.') ? path.split('.').last.toLowerCase() : 'img';
    final safeExtension =
        RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension) ? extension : 'img';
    return (await File(path)
            .copy('${media.path}/${const Uuid().v4()}.$safeExtension'))
        .path;
  }
}
