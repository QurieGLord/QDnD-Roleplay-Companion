// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestAdapter extends TypeAdapter<Quest> {
  @override
  final int typeId = 22;

  @override
  Quest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quest(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as QuestStatus,
      objectives: (fields[4] as List).cast<QuestObjective>(),
      imagePath: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      completedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Quest obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.objectives)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestObjectiveAdapter extends TypeAdapter<QuestObjective> {
  @override
  final int typeId = 23;

  @override
  QuestObjective read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuestObjective(
      description: fields[0] as String,
      isCompleted: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuestObjective obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestObjectiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestStatusAdapter extends TypeAdapter<QuestStatus> {
  @override
  final int typeId = 24;

  @override
  QuestStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QuestStatus.active;
      case 1:
        return QuestStatus.completed;
      case 2:
        return QuestStatus.failed;
      default:
        return QuestStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, QuestStatus obj) {
    switch (obj) {
      case QuestStatus.active:
        writer.writeByte(0);
        break;
      case QuestStatus.completed:
        writer.writeByte(1);
        break;
      case QuestStatus.failed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
