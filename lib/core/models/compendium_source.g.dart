// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compendium_source.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompendiumSourceAdapter extends TypeAdapter<CompendiumSource> {
  @override
  final int typeId = 26;

  @override
  CompendiumSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompendiumSource(
      id: fields[0] as String,
      name: fields[1] as String,
      importedAt: fields[2] as DateTime,
      itemCount: fields[3] == null ? 0 : fields[3] as int,
      spellCount: fields[4] == null ? 0 : fields[4] as int,
      raceCount: fields[5] == null ? 0 : fields[5] as int,
      classCount: fields[6] == null ? 0 : fields[6] as int,
      backgroundCount: fields[7] == null ? 0 : fields[7] as int,
      featCount: fields[8] == null ? 0 : fields[8] as int,
      archiveId: fields[9] as String?,
      archiveName: fields[10] as String?,
      moduleName: fields[11] as String?,
      modulePath: fields[12] as String?,
      sourceKind: fields[13] == null ? 'xml' : fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CompendiumSource obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.importedAt)
      ..writeByte(3)
      ..write(obj.itemCount)
      ..writeByte(4)
      ..write(obj.spellCount)
      ..writeByte(5)
      ..write(obj.raceCount)
      ..writeByte(6)
      ..write(obj.classCount)
      ..writeByte(7)
      ..write(obj.backgroundCount)
      ..writeByte(8)
      ..write(obj.featCount)
      ..writeByte(9)
      ..write(obj.archiveId)
      ..writeByte(10)
      ..write(obj.archiveName)
      ..writeByte(11)
      ..write(obj.moduleName)
      ..writeByte(12)
      ..write(obj.modulePath)
      ..writeByte(13)
      ..write(obj.sourceKind);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompendiumSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
