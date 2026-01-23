// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_note.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalNoteAdapter extends TypeAdapter<JournalNote> {
  @override
  final int typeId = 20;

  @override
  JournalNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalNote(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      category: fields[3] as NoteCategory,
      imagePath: fields[4] as String?,
      tags: (fields[5] as List).cast<String>(),
      isPinned: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, JournalNote obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteCategoryAdapter extends TypeAdapter<NoteCategory> {
  @override
  final int typeId = 21;

  @override
  NoteCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NoteCategory.general;
      case 1:
        return NoteCategory.location;
      case 2:
        return NoteCategory.npc;
      case 3:
        return NoteCategory.artifact;
      case 4:
        return NoteCategory.story;
      case 5:
        return NoteCategory.session;
      default:
        return NoteCategory.general;
    }
  }

  @override
  void write(BinaryWriter writer, NoteCategory obj) {
    switch (obj) {
      case NoteCategory.general:
        writer.writeByte(0);
        break;
      case NoteCategory.location:
        writer.writeByte(1);
        break;
      case NoteCategory.npc:
        writer.writeByte(2);
        break;
      case NoteCategory.artifact:
        writer.writeByte(3);
        break;
      case NoteCategory.story:
        writer.writeByte(4);
        break;
      case NoteCategory.session:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
