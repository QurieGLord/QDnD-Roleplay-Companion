import 'package:hive/hive.dart';

part 'compendium_source.g.dart';

@HiveType(typeId: 26)
class CompendiumSource extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // Filename or user-friendly name

  @HiveField(2)
  DateTime importedAt;

  @HiveField(3, defaultValue: 0)
  int itemCount;

  @HiveField(4, defaultValue: 0)
  int spellCount;

  @HiveField(5, defaultValue: 0)
  int raceCount;

  @HiveField(6, defaultValue: 0)
  int classCount;

  @HiveField(7, defaultValue: 0)
  int backgroundCount;

  @HiveField(8, defaultValue: 0)
  int featCount;

  @HiveField(9, defaultValue: null)
  String? archiveId;

  @HiveField(10, defaultValue: null)
  String? archiveName;

  @HiveField(11, defaultValue: null)
  String? moduleName;

  @HiveField(12, defaultValue: null)
  String? modulePath;

  @HiveField(13, defaultValue: 'xml')
  String sourceKind;

  CompendiumSource({
    required this.id,
    required this.name,
    required this.importedAt,
    this.itemCount = 0,
    this.spellCount = 0,
    this.raceCount = 0,
    this.classCount = 0,
    this.backgroundCount = 0,
    this.featCount = 0,
    this.archiveId,
    this.archiveName,
    this.moduleName,
    this.modulePath,
    this.sourceKind = 'xml',
  });
}
