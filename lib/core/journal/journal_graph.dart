import 'package:uuid/uuid.dart';

/// Stable identities are independent of spelling, record titles and text offsets.
enum JournalEntityKind { person, place, item, event, story }

class JournalEntity {
  JournalEntity(
      {String? id,
      required this.name,
      this.kind = JournalEntityKind.person,
      List<String>? aliases,
      this.description = ''})
      : id = id ?? const Uuid().v4(),
        aliases = List.of(aliases ?? []);
  final String id;
  String name;
  JournalEntityKind kind;
  List<String> aliases;
  String description;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'aliases': aliases,
        'description': description
      };
  factory JournalEntity.fromJson(Map<String, dynamic> json) => JournalEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: JournalEntityKind.values.firstWhere((k) => k.name == json['kind'],
          orElse: () => JournalEntityKind.story),
      aliases: List<String>.from(json['aliases'] ?? []),
      description: json['description'] as String? ?? '');
}

class JournalRecordLinks {
  JournalRecordLinks(
      {Set<String>? manual,
      Set<String>? automatic,
      Set<String>? excluded,
      Set<String>? records,
      this.session})
      : manual = Set.of(manual ?? {}),
        automatic = Set.of(automatic ?? {}),
        excluded = Set.of(excluded ?? {}),
        records = Set.of(records ?? {});
  Set<String> manual;
  Set<String> automatic;
  Set<String> excluded;
  Set<String> records;
  int? session;
  Set<String> get entities => {...manual, ...automatic}.difference(excluded);
  Map<String, dynamic> toJson() => {
        'manual': manual.toList(),
        'automatic': automatic.toList(),
        'excluded': excluded.toList(),
        'records': records.toList(),
        'session': session
      };
  factory JournalRecordLinks.fromJson(Map<String, dynamic> json) =>
      JournalRecordLinks(
          manual: Set<String>.from(json['manual'] ?? []),
          automatic: Set<String>.from(json['automatic'] ?? []),
          excluded: Set<String>.from(json['excluded'] ?? []),
          records: Set<String>.from(json['records'] ?? []),
          session: json['session'] as int?);
}

class JournalGraph {
  JournalGraph(
      {List<JournalEntity>? entities,
      Map<String, JournalRecordLinks>? records,
      List<String>? noteOrder,
      List<String>? questOrder,
      this.sessions = 0})
      : entities = List.of(entities ?? []),
        records = Map.of(records ?? {}),
        noteOrder = List.of(noteOrder ?? []),
        questOrder = List.of(questOrder ?? []);
  final List<String> noteOrder, questOrder;
  final List<JournalEntity> entities;
  final Map<String, JournalRecordLinks> records;

  /// Sessions the player has opened on the tape. The current session is the
  /// latest of these and of any session a record was written in.
  int sessions;
  int get currentSession => [
        sessions,
        1,
        for (final r in records.values)
          if (r.session != null) r.session!
      ].reduce((a, b) => a > b ? a : b);
  int countIn(int session) =>
      records.values.where((r) => r.session == session).length;
  JournalRecordLinks forRecord(String key) =>
      records.putIfAbsent(key, JournalRecordLinks.new);
  JournalEntity? entity(String id) {
    for (final e in entities) {
      if (e.id == id) return e;
    }
    return null;
  }

  void removeRecord(String key) {
    records.remove(key);
    noteOrder.remove(key);
    questOrder.remove(key);
    for (final r in records.values) {
      r.records.remove(key);
    }
  }

  void removeEntity(String id) {
    entities.removeWhere((e) => e.id == id);
    for (final r in records.values) {
      r.manual.remove(id);
      r.automatic.remove(id);
      r.excluded.remove(id);
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'noteOrder': noteOrder,
        'questOrder': questOrder,
        'sessions': sessions,
        'entities': entities.map((e) => e.toJson()).toList(),
        'records': records.map((key, value) => MapEntry(key, value.toJson()))
      };
  factory JournalGraph.fromJson(Map<dynamic, dynamic>? json) => JournalGraph(
      noteOrder: List<String>.from(json?['noteOrder'] ?? []),
      questOrder: List<String>.from(json?['questOrder'] ?? []),
      sessions: json?['sessions'] as int? ?? 0,
      entities: (json?['entities'] as List? ?? [])
          .map((e) =>
              JournalEntity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      records: (json?['records'] as Map? ?? {}).map((key, value) => MapEntry(
          key as String,
          JournalRecordLinks.fromJson(
              Map<String, dynamic>.from(value as Map)))));
  JournalGraph copy() => JournalGraph.fromJson(toJson());
}
