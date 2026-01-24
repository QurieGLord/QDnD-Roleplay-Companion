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

  @HiveField(3)
  int itemCount;

  @HiveField(4)
  int spellCount;

  CompendiumSource({
    required this.id,
    required this.name,
    required this.importedAt,
    this.itemCount = 0,
    this.spellCount = 0,
  });
}
